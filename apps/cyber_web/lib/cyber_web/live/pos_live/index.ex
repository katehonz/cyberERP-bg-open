defmodule CyberWeb.PosLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Sales
  alias CyberCore.Contacts
  alias Decimal, as: D
  alias Ecto.Changeset
  alias Phoenix.Naming

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    warehouses = Inventory.list_warehouses(@tenant_id)
    products = Inventory.list_products(@tenant_id)
    customers = load_customers()

    default_warehouse_id =
      case warehouses do
        [%{id: id} | _] -> id
        _ -> nil
      end

    categories = get_product_categories(products)

    {:ok,
     socket
     |> assign(:page_title, "POS продажби")
     |> assign(:product_search, "")
     |> assign(:products, products)
     |> assign(:filtered_products, products)
     |> assign(:selected_category, "all")
     |> assign(:categories, categories)
     |> assign(:cart, [])
     |> assign(:totals, totals_for([]))
     |> assign(:customers, customers)
     |> assign(:selected_customer_id, nil)
     |> assign(:warehouses, warehouses)
     |> assign(:selected_warehouse_id, default_warehouse_id)
     |> assign(:payment_method, "cash")
     |> assign(:invoice_number, generate_invoice_number())
     |> assign(:pos_reference, generate_pos_reference())
     |> assign(:notes, "")
     |> assign(:status_message, nil)
     |> assign(:status_type, :info)
     |> assign(:show_receipt_modal, false)
     |> assign(:last_sale, nil)
     |> assign(:barcode_input, "")
     |> assign(:show_search_modal, false)}
  end

  @impl true
  def handle_event("search_products", %{"search" => search}, socket) do
    search = String.trim(search)
    filtered = filter_products(socket.assigns.products, search, socket.assigns.selected_category)

    {:noreply,
     socket
     |> assign(:product_search, search)
     |> assign(:filtered_products, filtered)}
  end

  def handle_event("select_category", %{"category" => category}, socket) do
    filtered = filter_products(socket.assigns.products, socket.assigns.product_search, category)

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:filtered_products, filtered)}
  end

  def handle_event("add_to_cart", %{"product-id" => product_id}, socket) do
    product_id = String.to_integer(product_id)

    case Enum.find(socket.assigns.products, &(&1.id == product_id)) do
      nil ->
        {:noreply, socket}

      product ->
        cart = add_product_to_cart(socket.assigns.cart, product)

        {:noreply,
         socket
         |> assign(:cart, cart)
         |> assign(:totals, totals_for(cart))
         |> assign(:show_search_modal, false)
         |> put_status(:info, "Добавен: #{product.name}")}
    end
  end

  def handle_event("remove_line", %{"id" => id}, socket) do
    id = String.to_integer(id)
    cart = Enum.reject(socket.assigns.cart, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:cart, cart)
     |> assign(:totals, totals_for(cart))}
  end

  def handle_event("update_cart", %{"cart" => cart_params}, socket) do
    cart =
      cart_params
      |> Enum.map(fn {id, params} ->
        id = String.to_integer(id)

        %{
          id: id,
          product_id: parse_integer(params["product_id"]),
          name: params["name"],
          sku: params["sku"],
          unit: params["unit"] || "бр.",
          quantity: to_decimal(params["quantity"] || "1"),
          unit_price: to_decimal(params["unit_price"] || "0"),
          discount_percent: to_decimal(params["discount_percent"] || "0"),
          tax_rate: to_decimal(params["tax_rate"] || "20")
        }
      end)

    {:noreply,
     socket
     |> assign(:cart, cart)
     |> assign(:totals, totals_for(cart))}
  end

  def handle_event("select_customer", %{"customer_id" => customer_id}, socket) do
    {:noreply, assign(socket, :selected_customer_id, parse_integer(customer_id))}
  end

  def handle_event("select_warehouse", %{"warehouse_id" => warehouse_id}, socket) do
    {:noreply, assign(socket, :selected_warehouse_id, parse_integer(warehouse_id))}
  end

  def handle_event("change_payment", %{"payment_method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :notes, notes)}
  end

  def handle_event("clear_cart", _params, socket) do
    {:noreply,
     socket
     |> assign(:cart, [])
     |> assign(:totals, totals_for([]))}
  end

  def handle_event("finalize_sale", _params, socket) do
    cart = socket.assigns.cart

    cond do
      cart == [] ->
        {:noreply, put_status(socket, :error, "Няма артикули в кошницата")}

      is_nil(socket.assigns.selected_warehouse_id) ->
        {:noreply, put_status(socket, :error, "Изберете склад за продажбата")}

      true ->
        do_finalize_sale(socket)
    end
  end

  def handle_event("close_receipt", _params, socket) do
    {:noreply, assign(socket, :show_receipt_modal, false)}
  end

  def handle_event("print_receipt", _params, socket) do
    # Тук може да се имплементира реална печат на фискален бон
    {:noreply, socket}
  end

  def handle_event("barcode_scan", %{"barcode" => barcode}, socket) do
    barcode = String.trim(barcode)

    if barcode != "" do
      case find_product_by_barcode(socket.assigns.products, barcode) do
        nil ->
          {:noreply,
           socket
           |> assign(:barcode_input, "")
           |> put_status(:error, "Продукт с баркод '#{barcode}' не е намерен")}

        product ->
          cart = add_product_to_cart(socket.assigns.cart, product)

          {:noreply,
           socket
           |> assign(:cart, cart)
           |> assign(:totals, totals_for(cart))
           |> assign(:barcode_input, "")
           |> put_status(:info, "Добавен: #{product.name}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_search_modal", _params, socket) do
    {:noreply, assign(socket, :show_search_modal, true)}
  end

  def handle_event("hide_search_modal", _params, socket) do
    {:noreply, assign(socket, :show_search_modal, false)}
  end

  defp do_finalize_sale(socket) do
    cart = socket.assigns.cart
    totals = socket.assigns.totals
    customer = find_customer(socket.assigns.customers, socket.assigns.selected_customer_id)
    customer_name = (customer && customer.name) || "POS клиент"
    sale_items = Enum.with_index(cart, 1) |> Enum.map(&cart_line_to_sale_item/1)

    sale_attrs = %{
      tenant_id: @tenant_id,
      invoice_number: socket.assigns.invoice_number,
      customer_id: customer && customer.id,
      customer_name: customer_name,
      customer_phone: customer && customer.phone,
      customer_email: customer && customer.email,
      date: DateTime.utc_now(),
      amount: totals.total,
      status: "paid",
      warehouse_id: socket.assigns.selected_warehouse_id,
      payment_method: socket.assigns.payment_method,
      pos_reference: socket.assigns.pos_reference,
      notes: socket.assigns.notes
    }

    case Sales.create_sale_with_items(sale_attrs, sale_items) do
      {:ok, sale} ->
        sale_with_items = Sales.get_sale!(@tenant_id, sale.id, [:customer, :sale_items])

        {:noreply,
         socket
         |> assign(:cart, [])
         |> assign(:totals, totals_for([]))
         |> assign(:invoice_number, generate_invoice_number())
         |> assign(:pos_reference, generate_pos_reference())
         |> assign(:notes, "")
         |> assign(:last_sale, sale_with_items)
         |> assign(:show_receipt_modal, true)
         |> put_status(:success, "Продажбата беше записана успешно")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_status(socket, :error, humanize_changeset_errors(changeset))}

      {:error, reason} ->
        {:noreply, put_status(socket, :error, "Грешка при запис: #{inspect(reason)}")}
    end
  end

  defp cart_line_to_sale_item({line, index}) do
    %{
      line_no: index,
      product_id: line.product_id,
      description: line.name,
      sku: line.sku,
      unit: line.unit,
      quantity: line.quantity,
      unit_price: line.unit_price,
      discount_percent: line.discount_percent,
      tax_rate: line.tax_rate
    }
  end

  defp add_product_to_cart(cart, product) do
    case Enum.find(cart, &(&1.product_id == product.id)) do
      nil ->
        cart ++
          [
            %{
              id: System.unique_integer([:positive]),
              product_id: product.id,
              name: product.name,
              sku: product.sku,
              unit: product.unit || "бр.",
              quantity: D.new(1),
              unit_price: product.price || D.new(0),
              discount_percent: D.new(0),
              tax_rate: D.new("20")
            }
          ]

      existing ->
        updated = %{existing | quantity: D.add(existing.quantity, D.new(1))}
        Enum.map(cart, fn item -> if item.product_id == product.id, do: updated, else: item end)
    end
  end

  defp totals_for(cart) do
    Enum.reduce(cart, %{subtotal: D.new(0), tax: D.new(0), total: D.new(0)}, fn line, acc ->
      gross = D.mult(line.quantity, line.unit_price)
      discount_amount = gross |> D.mult(line.discount_percent) |> D.div(D.new(100))
      subtotal = D.sub(gross, discount_amount)
      tax = subtotal |> D.mult(line.tax_rate) |> D.div(D.new(100))
      total = D.add(subtotal, tax)

      %{
        subtotal: D.add(acc.subtotal, subtotal),
        tax: D.add(acc.tax, tax),
        total: D.add(acc.total, total)
      }
    end)
  end

  defp filter_products(products, search, category) do
    products
    |> filter_by_category(category)
    |> filter_by_search(search)
  end

  defp filter_by_category(products, "all"), do: products

  defp filter_by_category(products, category) do
    Enum.filter(products, fn product ->
      product.category == category
    end)
  end

  defp filter_by_search(products, ""), do: products

  defp filter_by_search(products, term) do
    down = String.downcase(term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name || ""), down) or
        String.contains?(String.downcase(product.sku || ""), down)
    end)
  end

  defp get_product_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp load_customers do
    Contacts.list_contacts(@tenant_id, is_customer: true)
    |> Enum.map(fn customer ->
      %{
        id: customer.id,
        name: customer.name,
        email: customer.email,
        phone: customer.phone
      }
    end)
  end

  defp find_customer(_customers, nil), do: nil
  defp find_customer(customers, id), do: Enum.find(customers, &(&1.id == id))

  defp find_product_by_barcode(products, barcode) do
    Enum.find(products, fn product ->
      (product.sku || "") == barcode || (product.barcode || "") == barcode
    end)
  end

  defp to_decimal(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        D.new(0)

      v ->
        case D.parse(v) do
          {:ok, decimal} -> decimal
          :error -> D.new(0)
        end
    end
  end

  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: D.new(value)
  defp to_decimal(value) when is_float(value), do: D.from_float(value)
  defp to_decimal(nil), do: D.new(0)

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp generate_invoice_number do
    date_part = Date.utc_today() |> Date.to_iso8601()
    unique = System.unique_integer([:positive])
    "POS-" <> date_part <> "-" <> Integer.to_string(unique)
  end

  defp generate_pos_reference do
    "POS-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp put_status(socket, type, message) do
    socket
    |> assign(:status_type, type)
    |> assign(:status_message, message)
  end

  defp humanize_changeset_errors(changeset) do
    changeset
    |> Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, messages} ->
      "#{Naming.humanize(field)}: #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp format_money(%Decimal{} = amount) do
    amount
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_integer(amount) do
    amount
    |> D.new()
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_float(amount) do
    amount
    |> D.from_float()
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(_), do: "0.00"

  defp format_decimal_string(value) do
    case String.split(value, ".") do
      [whole, decimals] ->
        padded = decimals |> String.pad_trailing(2, "0") |> String.slice(0, 2)
        whole <> "." <> padded

      [whole] ->
        whole <> ".00"
    end
  end

  defp payment_options do
    [
      {"В брой", "cash"},
      {"Карта", "card"},
      {"Банков превод", "bank_transfer"},
      {"Друг", "other"}
    ]
  end

  defp category_label("goods"), do: "Стоки"
  defp category_label("materials"), do: "Материали"
  defp category_label("services"), do: "Услуги"
  defp category_label("produced"), do: "Произведена продукция"
  defp category_label(category), do: category

  defp payment_method_label("cash"), do: "В брой"
  defp payment_method_label("card"), do: "Карта"
  defp payment_method_label("bank_transfer"), do: "Банков превод"
  defp payment_method_label("other"), do: "Друг"
  defp payment_method_label(method), do: method

  defp category_icon("goods") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
    </svg>
    """
  end

  defp category_icon("materials") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
    </svg>
    """
  end

  defp category_icon("services") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    """
  end

  defp category_icon("produced") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
    </svg>
    """
  end

  defp category_icon(_) do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
    </svg>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen bg-gradient-to-br from-slate-50 to-blue-50 p-4 font-sans">
      <.flash_group flash={@flash} />
      <div class="mx-auto grid h-full max-w-screen-2xl gap-6 lg:grid-cols-[1fr_2fr]">
        <!-- Лява част - Управление -->
        <div class="flex flex-col space-y-6 rounded-2xl bg-white p-6 shadow-2xl">
          <!-- Хедър -->
          <div>
            <h1 class="text-4xl font-bold text-gray-900">POS Каса</h1>
            <p class="mt-1 text-base text-gray-500">Бързи продажби с баркод</p>
          </div>

          <!-- Баркод скенер -->
          <div class="flex-1 pt-8">
            <form phx-submit="barcode_scan" phx-change="update_barcode" class="space-y-4">
              <label for="barcode-input" class="block text-lg font-semibold text-gray-800">
                Сканирай Баркод
              </label>
              <div class="relative">
                <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-4">
                  <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1v-2zM13 5a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 01-1 1h-2a1 1 0 01-1-1V5zM13 13a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 01-1 1h-2a1 1 0 01-1-1v-2z"></path></svg>
                </div>
                <input
                  type="text"
                  id="barcode-input"
                  name="barcode"
                  value={@barcode_input}
                  placeholder="Въведи или сканирай..."
                  class="w-full rounded-xl border-2 border-gray-300 bg-gray-50 p-4 pl-14 text-2xl font-mono focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500"
                  autofocus
                  phx-debounce="200"
                />
              </div>
              <button type="submit" class="hidden">Scan</button>
            </form>

            <div class="mt-8 text-center">
              <p class="text-gray-500">или</p>
              <button
                type="button"
                phx-click="show_search_modal"
                class="mt-4 inline-flex items-center gap-3 rounded-xl bg-indigo-600 px-8 py-4 text-lg font-semibold text-white shadow-lg transition hover:bg-indigo-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
              >
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
                Търси продукт ръчно
              </button>
            </div>
          </div>

          <!-- Детайли на продажбата -->
          <div class="space-y-4">
            <h3 class="border-t-2 border-gray-100 pt-6 text-xl font-bold text-gray-900">Детайли на продажбата</h3>
             <div>
                <label class="block text-sm font-semibold text-gray-600">Склад *</label>
                <select name="warehouse_id" phx-change="select_warehouse" class="mt-1 w-full rounded-lg border-gray-300 text-base focus:border-indigo-500 focus:ring-indigo-500">
                  <option value="">Изберете склад</option>
                  <%= for warehouse <- @warehouses do %>
                    <option value={warehouse.id} selected={@selected_warehouse_id == warehouse.id}><%= warehouse.name %></option>
                  <% end %>
                </select>
              </div>
            <div>
              <label class="block text-sm font-semibold text-gray-600">Клиент</label>
              <select name="customer_id" phx-change="select_customer" class="mt-1 w-full rounded-lg border-gray-300 text-base focus:border-indigo-500 focus:ring-indigo-500">
                <option value="">POS клиент</option>
                <%= for customer <- @customers do %>
                  <option value={customer.id} selected={@selected_customer_id == customer.id}><%= customer.name %></option>
                <% end %>
              </select>
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-600">Бележка</label>
              <textarea name="notes" rows="3" phx-change="update_notes" class="mt-1 w-full rounded-lg border-gray-300 text-base focus:border-indigo-500 focus:ring-indigo-500" placeholder="Допълнителна информация..."><%= @notes %></textarea>
            </div>
          </div>
        </div>

        <!-- Дясна част - Кошница и Плащане -->
        <div class="flex flex-col space-y-6 overflow-hidden rounded-2xl bg-white p-6 shadow-2xl">
          <!-- Кошница -->
          <div class="flex flex-1 flex-col overflow-hidden">
            <div class="flex items-center justify-between border-b-2 border-gray-100 pb-4">
              <div class="flex items-center gap-3">
                <svg class="h-8 w-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
                <h2 class="text-3xl font-bold text-gray-900">Кошница</h2>
              </div>
              <div class="flex items-center gap-4">
                 <span class="rounded-full bg-indigo-600 px-4 py-2 text-base font-bold text-white"><%= length(@cart) %> артикула</span>
                 <button type="button" phx-click="clear_cart" class="rounded-lg bg-red-100 px-4 py-2 text-sm font-medium text-red-700 transition hover:bg-red-200">
                    Изчисти
                 </button>
              </div>
            </div>

            <form phx-change="update_cart" class="flex-1 overflow-y-auto py-4 pr-2">
              <%= if @cart == [] do %>
                <div class="flex h-full items-center justify-center">
                  <div class="text-center">
                    <svg class="mx-auto h-24 w-24 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path></svg>
                    <p class="mt-6 text-xl font-medium text-gray-500">Кошницата е празна</p>
                    <p class="mt-2 text-base text-gray-400">Сканирайте баркод или добавете продукти ръчно</p>
                  </div>
                </div>
              <% else %>
                <div class="space-y-4">
                  <%= for item <- @cart do %>
                    <div class="group grid grid-cols-6 gap-4 items-center rounded-xl border-2 border-gray-200 bg-white p-3 transition hover:border-indigo-400 hover:shadow-lg">
                        <div class="col-span-3">
                          <p class="text-base font-bold text-gray-900 truncate"><%= item.name %></p>
                          <p class="text-sm text-gray-500">SKU: <%= item.sku %></p>
                        </div>
                        <div class="col-span-1">
                          <label class="block text-xs font-medium text-gray-600">Кол.</label>
                          <input type="number" step="0.01" name={"cart[#{item.id}][quantity]"} value={D.to_string(item.quantity)} class="mt-1 w-full rounded-md border-gray-300 text-center text-base focus:border-indigo-500 focus:ring-indigo-500" />
                        </div>
                        <div class="col-span-1">
                           <label class="block text-xs font-medium text-gray-600">Ед. цена</label>
                           <p class="text-base font-semibold text-gray-800 mt-1"><%= format_money(item.unit_price) %> лв.</p>
                        </div>
                        <div class="col-span-1 flex justify-end">
                            <button type="button" phx-click="remove_line" phx-value-id={item.id} class="rounded-md p-2 text-red-500 transition hover:bg-red-100 hover:text-red-600">
                                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                            </button>
                        </div>
                        <input type="hidden" name={"cart[#{item.id}][product_id]"} value={item.product_id} />
                        <input type="hidden" name={"cart[#{item.id}][name]"} value={item.name} />
                        <input type="hidden" name={"cart[#{item.id}][sku]"} value={item.sku} />
                        <input type="hidden" name={"cart[#{item.id}][unit]"} value={item.unit} />
                         <input type="hidden" name={"cart[#{item.id}][unit_price]"} value={D.to_string(item.unit_price)} />
                         <input type="hidden" name={"cart[#{item.id}][discount_percent]"} value={D.to_string(item.discount_percent)} />
                         <input type="hidden" name={"cart[#{item.id}][tax_rate]"} value={D.to_string(item.tax_rate)} />
                    </div>
                  <% end %>
                </div>
              <% end %>
            </form>
          </div>

          <!-- Суми и плащане -->
          <div class="border-t-2 border-gray-100 pt-6">
            <div class="grid grid-cols-2 gap-6">
                <!-- Суми -->
                <div class="space-y-3 text-lg">
                    <div class="flex items-center justify-between text-gray-600">
                      <span>Междинна сума</span>
                      <span class="font-semibold"><%= format_money(@totals.subtotal) %> лв.</span>
                    </div>
                    <div class="flex items-center justify-between text-gray-600">
                      <span>ДДС (20%)</span>
                      <span class="font-semibold"><%= format_money(@totals.tax) %> лв.</span>
                    </div>
                    <div class="flex items-center justify-between border-t-2 border-gray-300 pt-3 text-2xl">
                      <span class="font-bold text-gray-900">ОБЩО</span>
                      <span class="font-bold text-indigo-600"><%= format_money(@totals.total) %> лв.</span>
                    </div>
                </div>
                <!-- Плащане -->
                <div class="space-y-3">
                   <label class="block text-sm font-semibold text-gray-600">Метод на плащане</label>
                    <div class="grid grid-cols-2 gap-3">
                      <%= for {label, value} <- payment_options() do %>
                        <button
                          type="button"
                          phx-click="change_payment"
                          phx-value-payment_method={value}
                          class={"flex items-center justify-center gap-2 rounded-lg border-2 px-3 py-3 text-base font-medium transition " <> if @payment_method == value, do: "border-indigo-600 bg-indigo-50 text-indigo-700 shadow-md", else: "border-gray-200 bg-white text-gray-700 hover:border-indigo-300"}
                        >
                          <%= if value == "cash" do %><svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"></path></svg><% end %>
                          <%= if value == "card" do %><svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path></svg><% end %>
                          <span><%= label %></span>
                        </button>
                      <% end %>
                    </div>
                </div>
            </div>

            <%= if @status_message do %>
              <div class={"mt-4 rounded-lg p-4 text-base " <> if @status_type == :success, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}>
                <div class="flex items-center gap-3">
                  <%= if @status_type == :success do %><svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg><% end %>
                  <%= if @status_type == :error do %><svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg><% end %>
                  <span class="font-medium"><%= @status_message %></span>
                </div>
              </div>
            <% end %>

            <button
              type="button"
              phx-click="finalize_sale"
              disabled={@cart == []}
              class={"mt-6 w-full rounded-xl px-6 py-5 text-xl font-bold text-white shadow-lg transition-transform duration-150 ease-in-out " <> if @cart == [], do: "cursor-not-allowed bg-gray-400", else: "bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 hover:shadow-xl hover:scale-105"}
            >
              <div class="flex items-center justify-center gap-3">
                <svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span>Завърши и плати</span>
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- Модал за търсене на продукти -->
      <%= if @show_search_modal do %>
        <div class="fixed inset-0 z-50 flex items-start justify-center bg-black bg-opacity-60 p-4 pt-[10vh]">
          <div class="w-full max-w-4xl rounded-2xl bg-white shadow-2xl flex flex-col max-h-[80vh]" phx-click-away="hide_search_modal">
              <!-- Хедър на модала -->
              <div class="p-6 border-b-2 border-gray-100">
                  <div class="flex justify-between items-center">
                      <h2 class="text-2xl font-bold text-gray-900">Търсене на продукти</h2>
                      <button type="button" phx-click="hide_search_modal" class="p-2 rounded-full text-gray-400 hover:bg-gray-200 hover:text-gray-600">
                          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                      </button>
                  </div>
                   <!-- Търсене -->
                  <div class="mt-4">
                    <form phx-change="search_products" class="flex items-center gap-3">
                      <div class="relative flex-1">
                        <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                          <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                          </svg>
                        </div>
                        <input
                          type="text"
                          name="search"
                          value={@product_search}
                          placeholder="Търсене по име или SKU..."
                          class="w-full rounded-lg border-gray-300 pl-10 text-base focus:border-indigo-500 focus:ring-indigo-500"
                        />
                      </div>
                    </form>

                    <!-- Категории -->
                    <div class="mt-4 flex gap-2 overflow-x-auto pb-2">
                      <button
                        type="button"
                        phx-click="select_category"
                        phx-value-category="all"
                        class={"inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition " <> if @selected_category == "all", do: "bg-indigo-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}
                      >
                        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path></svg>
                        <span>Всички</span>
                      </button>
                      <%= for category <- @categories do %>
                        <button
                          type="button"
                          phx-click="select_category"
                          phx-value-category={category}
                          class={"inline-flex items-center gap-2 whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition " <> if @selected_category == category, do: "bg-indigo-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}
                        >
                          <span :if={category_icon(category)} class="inline-block"><%= Phoenix.HTML.raw(category_icon(category)) %></span>
                          <span><%= category_label(category) %></span>
                        </button>
                      <% end %>
                    </div>
                  </div>
              </div>
              <!-- Продуктова мрежа в модал -->
              <div class="flex-1 overflow-y-auto p-6">
                <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                  <%= for product <- @filtered_products do %>
                    <button
                      type="button"
                      phx-click="add_to_cart"
                      phx-value-product-id={product.id}
                      class="group relative flex h-36 flex-col justify-between rounded-xl border-2 border-gray-200 bg-gradient-to-br from-white to-gray-50 p-4 text-left shadow-sm transition hover:border-indigo-500 hover:shadow-lg hover:-translate-y-1"
                    >
                      <div class="absolute right-3 top-3 opacity-0 transition-opacity group-hover:opacity-100">
                        <svg class="h-8 w-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                      </div>
                      <div>
                        <p class="text-base font-bold text-gray-900 line-clamp-2"><%= product.name %></p>
                        <p class="mt-1 text-sm text-gray-500">SKU: <%= product.sku %></p>
                      </div>
                      <div class="flex items-end justify-between">
                        <p class="text-xl font-bold text-indigo-600"><%= format_money(product.price || 0) %> лв.</p>
                        <span :if={product.category} class="text-xs font-medium text-gray-400"><%= category_label(product.category) %></span>
                      </div>
                    </button>
                  <% end %>
                </div>
                <%= if @filtered_products == [] do %>
                  <div class="flex h-64 items-center justify-center">
                    <div class="text-center">
                      <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path></svg>
                      <p class="mt-4 text-lg font-medium text-gray-900">Няма намерени продукти</p>
                      <p class="mt-1 text-sm text-gray-500">Опитайте с различна категория или търсене</p>
                    </div>
                  </div>
                <% end %>
              </div>
               <div class="p-4 bg-gray-50 border-t-2 border-gray-100 text-right">
                    <button type="button" phx-click="hide_search_modal" class="px-6 py-3 rounded-lg bg-gray-200 text-gray-800 font-semibold hover:bg-gray-300">Затвори</button>
               </div>
          </div>
        </div>
      <% end %>

      <!-- Модал за фискален бон -->
      <%= if @show_receipt_modal && @last_sale do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4" phx-click="close_receipt">
          <div class="max-w-md w-full rounded-xl bg-white shadow-2xl" onclick="event.stopPropagation()">
            <!-- Хедър -->
            <div class="border-b border-gray-200 bg-gradient-to-r from-green-50 to-emerald-50 p-6">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="rounded-full bg-green-500 p-2">
                    <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-lg font-bold text-gray-900">Продажбата е завършена!</h3>
                    <p class="text-sm text-gray-600">Фискален бон</p>
                  </div>
                </div>
                <button type="button" phx-click="close_receipt" class="rounded-lg p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-600">
                  <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Съдържание на бона -->
            <div class="max-h-[60vh] overflow-y-auto p-6">
              <div class="space-y-4 text-sm">
                <div class="text-center border-b border-gray-200 pb-4">
                  <p class="text-lg font-bold">ФИСКАЛЕН БОН</p>
                  <p class="text-xs text-gray-600 mt-1">CYBER ERP SYSTEM</p>
                </div>

                <div class="space-y-1 border-b border-gray-200 pb-3">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Фискален №:</span>
                    <span class="font-semibold"><%= @last_sale.invoice_number %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Дата:</span>
                    <span class="font-semibold"><%= Calendar.strftime(@last_sale.date, "%d.%m.%Y %H:%M") %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Клиент:</span>
                    <span class="font-semibold"><%= @last_sale.customer_name %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Плащане:</span>
                    <span class="font-semibold"><%= payment_method_label(@last_sale.payment_method) %></span>
                  </div>
                </div>

                <div class="space-y-2 border-b border-gray-200 pb-3">
                  <p class="font-semibold">Артикули:</p>
                  <%= for item <- @last_sale.sale_items do %>
                    <div class="space-y-1">
                      <div class="flex justify-between">
                        <span class="font-medium"><%= item.description %></span>
                      </div>
                      <div class="flex justify-between text-xs text-gray-600">
                        <span><%= D.to_string(item.quantity) %> x <%= format_money(item.unit_price) %> лв.</span>
                        <span class="font-semibold"><%= format_money(item.total_amount) %> лв.</span>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="space-y-1 text-base">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Сума без ДДС:</span>
                    <span class="font-semibold"><%= format_money(D.mult(@last_sale.amount, D.new("0.8333"))) %> лв.</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">ДДС (20%):</span>
                    <span class="font-semibold"><%= format_money(D.mult(@last_sale.amount, D.new("0.1667"))) %> лв.</span>
                  </div>
                  <div class="flex justify-between border-t-2 border-gray-300 pt-2 text-lg">
                    <span class="font-bold">ОБЩО:</span>
                    <span class="font-bold text-indigo-600"><%= format_money(@last_sale.amount) %> лв.</span>
                  </div>
                </div>

                <div class="text-center border-t border-gray-200 pt-4 text-xs text-gray-500">
                  <p>Благодарим Ви за покупката!</p>
                  <p class="mt-1">Запазете бона за евентуална рекламация</p>
                </div>
              </div>
            </div>

            <!-- Бутони -->
            <div class="border-t border-gray-200 p-4">
              <div class="flex gap-3">
                <button type="button" phx-click="print_receipt" class="flex-1 rounded-lg bg-indigo-600 px-4 py-3 text-sm font-semibold text-white hover:bg-indigo-700">
                  <div class="flex items-center justify-center gap-2">
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                    </svg>
                    <span>Принтирай</span>
                  </div>
                </button>
                <button type="button" phx-click="close_receipt" class="flex-1 rounded-lg bg-gray-200 px-4 py-3 text-sm font-semibold text-gray-700 hover:bg-gray-300">
                  Затвори
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
