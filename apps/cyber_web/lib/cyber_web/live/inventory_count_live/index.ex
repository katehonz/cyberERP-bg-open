defmodule CyberWeb.InventoryCountLive.Index do
  @moduledoc """
  Инвентаризация - преброяване на наличности и сравнение с очаквани количества.

  Процесът включва:
  1. Създаване на инвентаризация за определен склад
  2. Въвеждане на реално преброени количества
  3. Автоматично сравнение с наличности в системата
  4. Генериране на протоколи за Липса или Излишък
  """
  use CyberWeb, :live_view

  alias CyberCore.Inventory

  @impl true
  def mount(_params, _session, socket) do
    inventory_counts = list_inventory_counts()
    warehouses = Inventory.list_warehouses(1)

    {:ok,
     socket
     |> assign(:page_title, "Инвентаризация")
     |> assign(:inventory_counts, inventory_counts)
     |> assign(:warehouses, warehouses)
     |> assign(:selected_count, nil)
     |> assign(:form, to_form(%{
       "document_no" => generate_document_no(),
       "document_date" => Date.utc_today(),
       "warehouse_id" => nil,
       "notes" => ""
     }))
     |> assign(:count_lines, [])
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)
     |> assign(:selected_warehouse, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # live_action идва от рутера автоматично
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Инвентаризация")
    |> assign(:selected_count, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нова инвентаризация")
    |> assign(:form, to_form(%{
      "document_no" => generate_document_no(),
      "document_date" => Date.utc_today(),
      "warehouse_id" => nil,
      "notes" => ""
    }))
    |> assign(:count_lines, [])
    |> assign(:show_product_search_modal, false)
    |> assign(:product_search_line_index, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    # TODO: Load inventory count by ID
    socket
    |> assign(:page_title, "Инвентаризация ##{id}")
    |> assign(:selected_count, %{id: id})
  end

  # =====================================
  # Handle Events
  # =====================================

  @impl true
  def handle_event("start_count", %{"warehouse_id" => warehouse_id}, socket) when warehouse_id != "" do
    warehouse = Enum.find(socket.assigns.warehouses, &(&1.id == String.to_integer(warehouse_id)))
    stock_levels = Inventory.list_stock_levels(1, %{warehouse_id: warehouse_id})

    count_lines =
      Enum.map(stock_levels, fn level ->
        %{
          product_id: level.product_id,
          product_name: level.product.name,
          sku: level.product.sku,
          expected_qty: Decimal.to_float(level.quantity),
          counted_qty: nil,
          difference: nil,
          unit: level.product.unit || "бр.",
          status: :pending
        }
      end)

    {:noreply,
     socket
     |> assign(:count_lines, count_lines)
     |> assign(:selected_warehouse, warehouse)
     |> put_flash(:info, "Заредени #{length(count_lines)} артикула от склад \"#{warehouse.name}\"")}
  end

  def handle_event("start_count", _params, socket) do
    {:noreply, put_flash(socket, :error, "Моля изберете склад")}
  end

  def handle_event("update_count", %{"index" => index_str, "value" => value}, socket) do
    index = String.to_integer(index_str)
    counted_qty = parse_number(value)

    count_lines =
      List.update_at(socket.assigns.count_lines, index, fn line ->
        expected = line.expected_qty
        difference = if counted_qty, do: counted_qty - expected, else: nil

        status =
          cond do
            is_nil(difference) -> :pending
            difference == 0 -> :ok
            difference < 0 -> :shortage
            difference > 0 -> :surplus
          end

        %{line |
          counted_qty: counted_qty,
          difference: difference,
          status: status
        }
      end)

    {:noreply, assign(socket, :count_lines, count_lines)}
  end

  def handle_event("add_product", _, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, :new)}
  end

  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

  def handle_event("generate_adjustments", _, socket) do
    count_lines = socket.assigns.count_lines

    shortages = Enum.filter(count_lines, &(&1.status == :shortage))
    surpluses = Enum.filter(count_lines, &(&1.status == :surplus))

    message_parts = []

    message_parts =
      if length(shortages) > 0 do
        message_parts ++ ["#{length(shortages)} липси"]
      else
        message_parts
      end

    message_parts =
      if length(surpluses) > 0 do
        message_parts ++ ["#{length(surpluses)} излишъка"]
      else
        message_parts
      end

    if message_parts == [] do
      {:noreply, put_flash(socket, :info, "Няма разлики за генериране на протоколи.")}
    else
      # TODO: Actually create the adjustment documents
      {:noreply,
       socket
       |> put_flash(:info, "Ще бъдат генерирани: #{Enum.join(message_parts, " и ")}")}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    # TODO: Save inventory count
    {:noreply,
     socket
     |> put_flash(:info, "Инвентаризацията е запазена.")
     |> push_navigate(to: ~p"/inventory-counts")}
  end

  # =====================================
  # Handle Info
  # =====================================

  @impl true
  def handle_info({:search_modal_selected, %{item: product, field: :product_id}}, socket) do
    new_line = %{
      product_id: product.id,
      product_name: product.name,
      sku: product.sku,
      expected_qty: 0,
      counted_qty: nil,
      difference: nil,
      unit: product.unit || "бр.",
      status: :pending
    }

    count_lines = socket.assigns.count_lines ++ [new_line]

    {:noreply,
     socket
     |> assign(:count_lines, count_lines)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  def handle_info({:search_modal_cancelled, %{field: :product_id}}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  # =====================================
  # Render
  # =====================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <%= if @live_action == :index do %>
        <%= render_index(assigns) %>
      <% else %>
        <%= render_form(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_index(assigns) do
    ~H"""
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <div class="flex items-center gap-3">
          <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-indigo-100">
            <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
          </div>
          <div>
            <h1 class="text-2xl font-semibold text-gray-900">Инвентаризация</h1>
            <p class="mt-1 text-sm text-gray-700">Преброяване и сверка на складови наличности</p>
          </div>
        </div>
      </div>
      <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
        <.link
          navigate={~p"/inventory-counts/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
        >
          + Нова инвентаризация
        </.link>
      </div>
    </div>

    <div class="mt-8">
      <%= if @inventory_counts == [] do %>
        <div class="text-center py-12 bg-white rounded-lg shadow-sm ring-1 ring-gray-200">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
          <h3 class="mt-2 text-sm font-semibold text-gray-900">Няма инвентаризации</h3>
          <p class="mt-1 text-sm text-gray-500">Създайте нова инвентаризация за да започнете</p>
          <div class="mt-6">
            <.link
              navigate={~p"/inventory-counts/new"}
              class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              + Нова инвентаризация
            </.link>
          </div>
        </div>
      <% else %>
        <div class="bg-white shadow-sm ring-1 ring-gray-200 sm:rounded-lg">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900">Номер</th>
                <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Дата</th>
                <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Склад</th>
                <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Статус</th>
                <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">Действия</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= for count <- @inventory_counts do %>
                <tr>
                  <td class="py-4 pl-4 pr-3 text-sm font-medium text-gray-900"><%= count.document_no %></td>
                  <td class="px-3 py-4 text-sm text-gray-500"><%= count.document_date %></td>
                  <td class="px-3 py-4 text-sm text-gray-500"><%= count.warehouse_name %></td>
                  <td class="px-3 py-4 text-sm"><%= render_status(count.status) %></td>
                  <td class="px-3 py-4 text-right text-sm">
                    <.link navigate={~p"/inventory-counts/#{count.id}"} class="text-indigo-600 hover:text-indigo-900">
                      Преглед
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <div class="flex items-center gap-3">
          <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-indigo-100">
            <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
          </div>
          <div>
            <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
            <p class="mt-1 text-sm text-gray-700">Преброяване на стоки и сравнение с наличности</p>
          </div>
        </div>
      </div>
      <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
        <.link
          navigate={~p"/inventory-counts"}
          class="inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
        >
          ← Назад
        </.link>
      </div>
    </div>

    <div class="mt-8">
      <form phx-change="validate" phx-submit="save">
        <div class="bg-white shadow-sm ring-1 ring-indigo-200 sm:rounded-xl p-6">
          <!-- Header -->
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Номер</label>
              <input
                type="text"
                name="document_no"
                value={@form[:document_no].value}
                readonly
                class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Дата</label>
              <input
                type="date"
                name="document_date"
                value={@form[:document_date].value}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Склад <span class="text-red-500">*</span></label>
              <select
                name="warehouse_id"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Изберете склад...</option>
                <%= for warehouse <- @warehouses do %>
                  <option value={warehouse.id}><%= warehouse.name %></option>
                <% end %>
              </select>
            </div>

            <div class="flex items-end">
              <button
                type="button"
                phx-click="start_count"
                phx-value-warehouse_id={@form[:warehouse_id] && @form[:warehouse_id].value}
                class="w-full rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
              >
                Зареди артикули
              </button>
            </div>
          </div>

          <!-- Count Lines -->
          <div class="mt-8 border-t border-gray-200 pt-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-base font-medium text-gray-900">Артикули за преброяване</h3>
              <button
                type="button"
                phx-click="add_product"
                class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
              >
                + Добави артикул
              </button>
            </div>

            <%= if @count_lines == [] do %>
              <div class="text-center py-12 bg-gray-50 rounded-lg">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                </svg>
                <p class="mt-2 text-sm text-gray-500">Изберете склад и натиснете "Зареди артикули"</p>
                <p class="text-xs text-gray-400">или добавете артикули ръчно</p>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">SKU</th>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Продукт</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Очаквано</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Преброено</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Разлика</th>
                      <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase">Статус</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for {line, index} <- Enum.with_index(@count_lines) do %>
                      <tr class={line_row_class(line.status)}>
                        <td class="px-3 py-2 text-gray-500"><%= line.sku %></td>
                        <td class="px-3 py-2 font-medium text-gray-900"><%= line.product_name %></td>
                        <td class="px-3 py-2 text-right text-gray-600">
                          <%= :erlang.float_to_binary(line.expected_qty * 1.0, decimals: 2) %> <%= line.unit %>
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            step="0.001"
                            min="0"
                            value={line.counted_qty}
                            phx-blur="update_count"
                            phx-value-index={index}
                            phx-value-value={line.counted_qty}
                            class="block w-24 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            placeholder="0"
                          />
                        </td>
                        <td class={"px-3 py-2 text-right font-medium #{difference_class(line.difference)}"}>
                          <%= if line.difference do %>
                            <%= if line.difference > 0, do: "+" %><%= :erlang.float_to_binary(line.difference * 1.0, decimals: 2) %>
                          <% else %>
                            -
                          <% end %>
                        </td>
                        <td class="px-3 py-2 text-center">
                          <%= render_line_status(line.status) %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- Summary -->
              <div class="mt-6 flex justify-between items-start">
                <div class="flex gap-4 text-sm">
                  <div class="flex items-center gap-2">
                    <span class="inline-flex h-3 w-3 rounded-full bg-gray-300"></span>
                    <span class="text-gray-600">Чакащи: <%= count_by_status(@count_lines, :pending) %></span>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="inline-flex h-3 w-3 rounded-full bg-green-500"></span>
                    <span class="text-gray-600">OK: <%= count_by_status(@count_lines, :ok) %></span>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="inline-flex h-3 w-3 rounded-full bg-orange-500"></span>
                    <span class="text-gray-600">Липси: <%= count_by_status(@count_lines, :shortage) %></span>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="inline-flex h-3 w-3 rounded-full bg-blue-500"></span>
                    <span class="text-gray-600">Излишъци: <%= count_by_status(@count_lines, :surplus) %></span>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="generate_adjustments"
                  class="rounded-md bg-amber-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-amber-500"
                >
                  Генерирай протоколи
                </button>
              </div>
            <% end %>
          </div>

          <!-- Actions -->
          <div class="mt-8 flex items-center justify-end gap-x-4 border-t border-gray-200 pt-6">
            <.link
              navigate={~p"/inventory-counts"}
              class="text-sm font-semibold leading-6 text-gray-900 hover:text-gray-700"
            >
              Отказ
            </.link>
            <button
              type="submit"
              class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              Запази инвентаризацията
            </button>
          </div>
        </div>
      </form>
    </div>

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="product-search-modal"
      show={@show_product_search_modal}
      title="Търсене на продукт"
      search_fun={&Inventory.search_products(1, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:sku, "text-sm text-gray-600", fn v -> "SKU: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:product_id}
    />
    """
  end

  # =====================================
  # Helpers
  # =====================================

  defp list_inventory_counts do
    # TODO: Implement actual query
    []
  end

  defp generate_document_no do
    "ИНВ-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"
  end

  defp parse_number(value) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_number(_), do: nil

  defp count_by_status(lines, status) do
    Enum.count(lines, &(&1.status == status))
  end

  defp line_row_class(:ok), do: "bg-green-50"
  defp line_row_class(:shortage), do: "bg-orange-50"
  defp line_row_class(:surplus), do: "bg-blue-50"
  defp line_row_class(_), do: ""

  defp difference_class(nil), do: "text-gray-400"
  defp difference_class(diff) when diff == 0, do: "text-green-600"
  defp difference_class(diff) when diff < 0, do: "text-orange-600"
  defp difference_class(diff) when diff > 0, do: "text-blue-600"

  defp render_status(:draft) do
    assigns = %{}
    ~H"""
    <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
      Чернова
    </span>
    """
  end

  defp render_status(:in_progress) do
    assigns = %{}
    ~H"""
    <span class="inline-flex items-center rounded-full bg-yellow-100 px-2.5 py-0.5 text-xs font-medium text-yellow-800">
      В процес
    </span>
    """
  end

  defp render_status(:completed) do
    assigns = %{}
    ~H"""
    <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
      Завършена
    </span>
    """
  end

  defp render_status(_), do: nil

  defp render_line_status(:pending) do
    assigns = %{}
    ~H"""
    <span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-gray-200">
      <span class="text-xs text-gray-600">?</span>
    </span>
    """
  end

  defp render_line_status(:ok) do
    assigns = %{}
    ~H"""
    <span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-green-500">
      <svg class="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
      </svg>
    </span>
    """
  end

  defp render_line_status(:shortage) do
    assigns = %{}
    ~H"""
    <span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-orange-500">
      <svg class="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M20 12H4" />
      </svg>
    </span>
    """
  end

  defp render_line_status(:surplus) do
    assigns = %{}
    ~H"""
    <span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-blue-500">
      <svg class="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4" />
      </svg>
    </span>
    """
  end
end
