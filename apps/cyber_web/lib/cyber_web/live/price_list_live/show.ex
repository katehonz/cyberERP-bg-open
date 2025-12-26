defmodule CyberWeb.PriceListLive.Show do
  use CyberWeb, :live_view

  alias Phoenix.LiveView.JS
  alias CyberCore.Repo
  alias CyberCore.Sales.PriceLists
  alias CyberCore.Sales.PriceListItem
  alias CyberCore.Inventory

  @tenant_id 1

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    price_list = PriceLists.get_price_list!(id) |> Repo.preload([:currency, price_list_items: :product])
    products = Inventory.list_products(@tenant_id)

    # Filter out products already in the price list
    existing_product_ids = Enum.map(price_list.price_list_items, & &1.product_id)
    available_products = Enum.reject(products, fn p -> p.id in existing_product_ids end)

    socket =
      socket
      |> assign(:page_title, price_list.name)
      |> assign(:price_list, price_list)
      |> assign(:products, products)
      |> assign(:available_products, available_products)
      |> assign(:selected_product_id, nil)
      |> assign(:base_price, nil)
      |> assign(:markup_percent, "20")
      |> assign(:calculated_price, nil)
      |> assign(:bulk_markup, "20")
      |> assign(:editing_item_id, nil)
      |> assign(:edit_price, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_product", %{"product_id" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:selected_product_id, nil)
     |> assign(:base_price, nil)
     |> assign(:calculated_price, nil)}
  end

  def handle_event("select_product", %{"product_id" => product_id}, socket) do
    product = Enum.find(socket.assigns.products, fn p -> to_string(p.id) == product_id end)

    base_price = if product, do: product.cost || product.price || Decimal.new(0), else: nil
    markup = parse_decimal(socket.assigns.markup_percent)
    calculated = calculate_markup_price(base_price, markup)

    {:noreply,
     socket
     |> assign(:selected_product_id, product_id)
     |> assign(:base_price, base_price)
     |> assign(:calculated_price, calculated)}
  end

  def handle_event("update_markup", %{"markup" => markup_str}, socket) do
    markup = parse_decimal(markup_str)
    calculated = calculate_markup_price(socket.assigns.base_price, markup)

    {:noreply,
     socket
     |> assign(:markup_percent, markup_str)
     |> assign(:calculated_price, calculated)}
  end

  def handle_event("update_price", %{"price" => price_str}, socket) do
    {:noreply, assign(socket, :calculated_price, price_str)}
  end

  def handle_event("add_item", _params, socket) do
    price_list_id = socket.assigns.price_list.id
    product_id = socket.assigns.selected_product_id
    price = socket.assigns.calculated_price

    if product_id && price do
      params = %{
        "price_list_id" => price_list_id,
        "product_id" => product_id,
        "price" => price
      }

      case PriceLists.create_price_list_item(params) do
        {:ok, _} ->
          {:noreply, reload_price_list(socket, "Артикулът е добавен.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Грешка при добавяне.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Изберете продукт и цена.")}
    end
  end

  def handle_event("apply_bulk_markup", %{"bulk_markup" => markup_str}, socket) do
    markup = parse_decimal(markup_str)
    price_list = socket.assigns.price_list

    # Get all products not in the price list yet
    existing_product_ids = Enum.map(price_list.price_list_items, & &1.product_id)
    products_to_add = Enum.reject(socket.assigns.products, fn p -> p.id in existing_product_ids end)

    # Add each product with calculated markup
    Enum.each(products_to_add, fn product ->
      base_price = product.cost || product.price || Decimal.new(0)
      calculated_price = calculate_markup_price(base_price, markup)

      if calculated_price do
        PriceLists.create_price_list_item(%{
          "price_list_id" => price_list.id,
          "product_id" => product.id,
          "price" => calculated_price
        })
      end
    end)

    {:noreply,
     socket
     |> reload_price_list("Добавени #{length(products_to_add)} артикула с #{markup_str}% надценка.")
     |> assign(:bulk_markup, markup_str)}
  end

  def handle_event("start_edit", %{"id" => item_id}, socket) do
    item = Enum.find(socket.assigns.price_list.price_list_items, fn i -> to_string(i.id) == item_id end)

    {:noreply,
     socket
     |> assign(:editing_item_id, item_id)
     |> assign(:edit_price, Decimal.to_string(item.price))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_item_id, nil)
     |> assign(:edit_price, nil)}
  end

  def handle_event("update_edit_price", %{"price" => price}, socket) do
    {:noreply, assign(socket, :edit_price, price)}
  end

  def handle_event("save_edit", %{"id" => item_id}, socket) do
    item = PriceLists.get_price_list_item!(item_id)

    case PriceLists.update_price_list_item(item, %{"price" => socket.assigns.edit_price}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_price_list("Цената е обновена.")
         |> assign(:editing_item_id, nil)
         |> assign(:edit_price, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при запис.")}
    end
  end

  def handle_event("delete_item", %{"id" => item_id}, socket) do
    item = PriceLists.get_price_list_item!(item_id)
    {:ok, _} = PriceLists.delete_price_list_item(item)

    {:noreply, reload_price_list(socket, "Артикулът е премахнат.")}
  end

  def handle_event("recalculate_item", %{"id" => item_id, "markup" => markup_str}, socket) do
    item = Enum.find(socket.assigns.price_list.price_list_items, fn i -> to_string(i.id) == to_string(item_id) end)

    if item do
      markup = parse_decimal(markup_str)
      base_price = item.product.cost || item.product.price || Decimal.new(0)
      new_price = calculate_markup_price(base_price, markup)

      if new_price do
        db_item = PriceLists.get_price_list_item!(item_id)
        PriceLists.update_price_list_item(db_item, %{"price" => new_price})
      end

      {:noreply, reload_price_list(socket, "Цената е преизчислена с #{markup_str}% надценка.")}
    else
      {:noreply, put_flash(socket, :error, "Артикулът не е намерен.")}
    end
  end

  defp reload_price_list(socket, message) do
    price_list_id = socket.assigns.price_list.id
    price_list = PriceLists.get_price_list!(price_list_id) |> Repo.preload([:currency, price_list_items: :product])

    existing_product_ids = Enum.map(price_list.price_list_items, & &1.product_id)
    available_products = Enum.reject(socket.assigns.products, fn p -> p.id in existing_product_ids end)

    socket
    |> put_flash(:info, message)
    |> assign(:price_list, price_list)
    |> assign(:available_products, available_products)
    |> assign(:selected_product_id, nil)
    |> assign(:base_price, nil)
    |> assign(:calculated_price, nil)
  end

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(""), do: Decimal.new(0)
  defp parse_decimal(str) when is_binary(str) do
    case Decimal.parse(str) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end
  defp parse_decimal(num), do: Decimal.new(num)

  defp calculate_markup_price(nil, _markup), do: nil
  defp calculate_markup_price(base_price, markup) do
    # Price = Base * (1 + markup/100)
    multiplier = Decimal.add(Decimal.new(1), Decimal.div(markup, Decimal.new(100)))
    Decimal.mult(base_price, multiplier) |> Decimal.round(2) |> Decimal.to_string()
  end

  defp calculate_markup_percent(base_price, current_price) when is_nil(base_price) or is_nil(current_price), do: "-"
  defp calculate_markup_percent(base_price, current_price) do
    base = if is_binary(base_price), do: Decimal.new(base_price), else: base_price
    current = if is_binary(current_price), do: Decimal.new(current_price), else: current_price

    if Decimal.compare(base, Decimal.new(0)) == :gt do
      # Markup = ((current - base) / base) * 100
      diff = Decimal.sub(current, base)
      percent = Decimal.div(diff, base) |> Decimal.mult(Decimal.new(100)) |> Decimal.round(1)
      "#{Decimal.to_string(percent)}%"
    else
      "-"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-zinc-900"><%= @page_title %></h1>
          <p class="text-sm text-zinc-600 mt-1">
            Тип: <%= if @price_list.type == "retail", do: "На дребно", else: "Стандартна" %>
            | Валута: <%= if @price_list.currency, do: @price_list.currency.code, else: "-" %>
          </p>
        </div>
        <.link navigate={~p"/price-lists"} class="text-sm text-indigo-600 hover:text-indigo-800">
          &larr; Към списъка
        </.link>
      </div>

      <!-- Add Single Product -->
      <div class="bg-white rounded-lg border border-gray-200 p-4">
        <h3 class="text-sm font-semibold text-zinc-900 mb-4">Добави продукт</h3>

        <div class="grid grid-cols-1 md:grid-cols-5 gap-4 items-end">
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Продукт</label>
            <select
              phx-change="select_product"
              name="product_id"
              class="w-full rounded-md border-gray-300 text-sm"
            >
              <option value="">-- Изберете продукт --</option>
              <%= for product <- @available_products do %>
                <option value={product.id} selected={to_string(product.id) == @selected_product_id}>
                  <%= product.name %>
                  (<%= if product.cost, do: "себест: #{product.cost}", else: if product.price, do: "цена: #{product.price}", else: "без цена" %>)
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Базова цена</label>
            <input
              type="text"
              value={if @base_price, do: Decimal.to_string(@base_price), else: "-"}
              disabled
              class="w-full rounded-md border-gray-300 bg-gray-100 text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Надценка %</label>
            <input
              type="number"
              step="0.1"
              value={@markup_percent}
              phx-change="update_markup"
              phx-debounce="300"
              name="markup"
              class="w-full rounded-md border-gray-300 text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Крайна цена</label>
            <div class="flex gap-2">
              <input
                type="number"
                step="0.01"
                value={@calculated_price}
                phx-change="update_price"
                name="price"
                class="w-full rounded-md border-gray-300 text-sm"
                placeholder="0.00"
              />
              <button
                phx-click="add_item"
                disabled={is_nil(@selected_product_id) or is_nil(@calculated_price)}
                class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                +
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Bulk Add -->
      <%= if length(@available_products) > 0 do %>
        <div class="bg-amber-50 rounded-lg border border-amber-200 p-4">
          <h3 class="text-sm font-semibold text-amber-900 mb-2">Бързо добавяне на всички продукти</h3>
          <p class="text-xs text-amber-700 mb-3">
            Добави <%= length(@available_products) %> оставащи продукта с единна надценка върху себестойността/цената им.
          </p>
          <form phx-submit="apply_bulk_markup" class="flex gap-3 items-end">
            <div>
              <label class="block text-sm font-medium text-amber-800 mb-1">Надценка %</label>
              <input
                type="number"
                step="0.1"
                name="bulk_markup"
                value={@bulk_markup}
                class="w-24 rounded-md border-amber-300 text-sm"
              />
            </div>
            <button
              type="submit"
              class="px-4 py-2 bg-amber-600 text-white rounded-md text-sm font-medium hover:bg-amber-700"
            >
              Добави всички с надценка
            </button>
          </form>
        </div>
      <% end %>

      <!-- Price List Items Table -->
      <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Продукт
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Себестойност
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Цена в листата
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Надценка
              </th>
              <th class="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wide text-gray-500">
                Преизчисли
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Действия
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for item <- @price_list.price_list_items do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= item.product.name %>
                  <div class="text-xs text-gray-500"><%= item.product.sku %></div>
                </td>
                <td class="px-4 py-3 text-right text-sm text-gray-500">
                  <%= item.product.cost || item.product.price || "-" %>
                </td>
                <td class="px-4 py-3 text-right text-sm">
                  <%= if @editing_item_id == to_string(item.id) do %>
                    <input
                      type="number"
                      step="0.01"
                      value={@edit_price}
                      phx-change="update_edit_price"
                      name="price"
                      class="w-24 rounded-md border-gray-300 text-sm text-right"
                      autofocus
                    />
                  <% else %>
                    <span class="font-semibold text-gray-900"><%= item.price %></span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-right text-sm">
                  <span class="text-green-600 font-medium">
                    <%= calculate_markup_percent(item.product.cost || item.product.price, item.price) %>
                  </span>
                </td>
                <td class="px-4 py-3 text-center">
                  <form phx-submit="recalculate_item" class="flex items-center justify-center gap-1">
                    <input type="hidden" name="id" value={item.id} />
                    <input
                      type="number"
                      step="1"
                      name="markup"
                      value="20"
                      class="w-16 rounded-md border-gray-300 text-xs text-center"
                    />
                    <button
                      type="submit"
                      class="p-1 text-indigo-600 hover:text-indigo-800"
                      title="Преизчисли с тази надценка"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                      </svg>
                    </button>
                  </form>
                </td>
                <td class="px-4 py-3 text-right text-sm space-x-2">
                  <%= if @editing_item_id == to_string(item.id) do %>
                    <button
                      phx-click="save_edit"
                      phx-value-id={item.id}
                      class="text-green-600 hover:text-green-800"
                    >
                      Запази
                    </button>
                    <button
                      phx-click="cancel_edit"
                      class="text-gray-600 hover:text-gray-800"
                    >
                      Откажи
                    </button>
                  <% else %>
                    <button
                      phx-click="start_edit"
                      phx-value-id={item.id}
                      class="text-indigo-600 hover:text-indigo-800"
                    >
                      Редакция
                    </button>
                    <button
                      phx-click="delete_item"
                      phx-value-id={item.id}
                      data-confirm="Сигурни ли сте?"
                      class="text-red-600 hover:text-red-800"
                    >
                      Изтрий
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if @price_list.price_list_items == [] do %>
          <div class="text-center py-12 text-gray-500">
            <p>Няма добавени артикули в ценовата листа.</p>
            <p class="text-sm mt-1">Използвайте формата по-горе за да добавите продукти.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
