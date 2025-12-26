defmodule CyberWeb.StockAdjustmentLive.FormComponent do
  @moduledoc """
  Корекция на складови наличности - Брак, Липса, Излишък.

  Типове:
  - scrap (Брак) - намалява наличността, дефектни продукти
  - shortage (Липса) - намалява наличността, неоткрити стоки
  - surplus (Излишък) - увеличава наличността, свръхнормни количества
  """
  use CyberWeb, :live_view

  alias CyberCore.Inventory

  @adjustment_types %{
    "scrap" => %{
      title: "Протокол за брак",
      description: "Бракуване на дефектни продукти - намалява наличността",
      prefix: "БР",
      color: "red",
      icon: "trash",
      direction: :decrease
    },
    "shortage" => %{
      title: "Протокол за липса",
      description: "Регистриране на липсващи стоки - намалява наличността",
      prefix: "ЛП",
      color: "orange",
      icon: "exclamation-triangle",
      direction: :decrease
    },
    "surplus" => %{
      title: "Протокол за излишък",
      description: "Регистриране на излишни стоки - увеличава наличността",
      prefix: "ИЗ",
      color: "green",
      icon: "plus-circle",
      direction: :increase
    }
  }

  @impl true
  def mount(%{"type" => type}, _session, socket) when type in ["scrap", "shortage", "surplus"] do
    warehouses = Inventory.list_warehouses(1)
    config = @adjustment_types[type]

    {:ok,
     socket
     |> assign(:adjustment_type, type)
     |> assign(:config, config)
     |> assign(:page_title, config.title)
     |> assign(:form, to_form(%{"document_no" => generate_document_no(config.prefix), "document_date" => Date.utc_today()}))
     |> assign(:lines, [])
     |> assign(:warehouses, warehouses)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Невалиден тип документ")
     |> push_navigate(to: ~p"/warehouse")}
  end

  # =====================================
  # Handle Events
  # =====================================

  @impl true
  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

  def handle_event("add_line", _, socket) do
    new_line = %{
      product: nil,
      product_id: nil,
      product_name: "",
      description: "",
      quantity: 1,
      unit: "бр.",
      unit_cost: 0,
      reason: ""
    }

    {:noreply, assign(socket, :lines, socket.assigns.lines ++ [new_line])}
  end

  def handle_event("remove_line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    lines = List.delete_at(socket.assigns.lines, index)
    {:noreply, assign(socket, :lines, lines)}
  end

  def handle_event("validate", %{"adjustment" => _params, "lines" => lines_params}, socket) do
    lines =
      Enum.map(lines_params, fn {idx, line_map} ->
        existing_line = Enum.at(socket.assigns.lines, String.to_integer(idx)) || %{}

        %{
          product: Map.get(existing_line, :product),
          product_id: Map.get(existing_line, :product_id),
          product_name: Map.get(existing_line, :product_name, ""),
          description: Map.get(line_map, "description", ""),
          quantity: parse_number(Map.get(line_map, "quantity", "1")),
          unit: Map.get(line_map, "unit", "бр."),
          unit_cost: parse_number(Map.get(line_map, "unit_cost", "0")),
          reason: Map.get(line_map, "reason", "")
        }
      end)

    {:noreply, assign(socket, :lines, lines)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"adjustment" => params, "lines" => lines_params}, socket) do
    lines =
      Enum.map(lines_params, fn {_i, line} ->
        %{
          "product_id" => line["product_id"],
          "quantity" => line["quantity"],
          "unit" => line["unit"],
          "unit_cost" => line["unit_cost"],
          "reason" => line["reason"]
        }
      end)

    attrs =
      params
      |> Map.put("tenant_id", 1)
      |> Map.put("adjustment_type", socket.assigns.adjustment_type)

    case Inventory.create_stock_adjustment(attrs, lines) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{socket.assigns.config.title} е създаден успешно.")
         |> push_navigate(to: ~p"/warehouse")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при създаване: #{inspect(reason)}")}
    end
  end

  def handle_event("save", _params, socket) do
    {:noreply, put_flash(socket, :error, "Моля добавете артикули към документа.")}
  end

  # =====================================
  # Handle Info
  # =====================================

  @impl true
  def handle_info({:search_modal_selected, %{item: product, field: :product_id}}, socket) do
    index = socket.assigns.product_search_line_index

    lines =
      List.update_at(socket.assigns.lines, index, fn line ->
        line
        |> Map.put(:product, product)
        |> Map.put(:product_id, product.id)
        |> Map.put(:product_name, product.name)
        |> Map.put(:description, product.description || product.name)
        |> Map.put(:unit, product.unit || "бр.")
        |> Map.put(:unit_cost, Decimal.to_float(product.cost || Decimal.new(0)))
      end)

    {:noreply,
     socket
     |> assign(:lines, lines)
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
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <div class="flex items-center gap-3">
            <%= render_icon(@config.icon, @config.color) %>
            <div>
              <h1 class={"text-2xl font-semibold text-#{@config.color}-900"}><%= @page_title %></h1>
              <p class="mt-1 text-sm text-gray-700"><%= @config.description %></p>
            </div>
          </div>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/warehouse"}
            class="inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
          >
            ← Назад
          </.link>
        </div>
      </div>

      <div class="mt-8">
        <div class={"bg-white shadow-sm ring-1 ring-#{@config.color}-200 sm:rounded-xl"}>
          <form phx-change="validate" phx-submit="save" class="p-6">
            <!-- Хедър информация -->
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Номер на документ <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  name="adjustment[document_no]"
                  value={@form[:document_no].value}
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Дата <span class="text-red-500">*</span>
                </label>
                <input
                  type="date"
                  name="adjustment[document_date]"
                  value={@form[:document_date].value}
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Склад <span class="text-red-500">*</span>
                </label>
                <select
                  name="adjustment[warehouse_id]"
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                >
                  <option value="">Изберете склад...</option>
                  <%= for warehouse <- @warehouses do %>
                    <option value={warehouse.id}><%= warehouse.name %></option>
                  <% end %>
                </select>
              </div>
            </div>

            <!-- Допълнителна информация -->
            <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Отговорно лице
                </label>
                <input
                  type="text"
                  name="adjustment[responsible_person]"
                  placeholder="Име на отговорното лице..."
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Комисия/Основание
                </label>
                <input
                  type="text"
                  name="adjustment[commission]"
                  placeholder="Протокол на комисия, инвентаризация..."
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>
            </div>

            <!-- Артикули -->
            <div class="mt-8 border-t border-gray-200 pt-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-base font-medium text-gray-900">Артикули</h3>
                <button
                  type="button"
                  phx-click="add_line"
                  class={"inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-#{@config.color}-700 bg-#{@config.color}-100 hover:bg-#{@config.color}-200"}
                >
                  + Добави ред
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Продукт</th>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Причина</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Количество</th>
                      <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Мярка</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Себестойност</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Стойност</th>
                      <th class="px-3 py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for {line, index} <- Enum.with_index(@lines) do %>
                      <tr>
                        <td class="px-3 py-2">
                          <div class="flex rounded-md shadow-sm">
                            <input
                              type="hidden"
                              name={"lines[#{index}][product_id]"}
                              value={line.product_id}
                            />
                            <input
                              type="text"
                              class="block w-full rounded-none rounded-l-md border-gray-300 bg-gray-50 sm:text-sm"
                              value={line.product_name}
                              readonly
                              placeholder="Изберете продукт..."
                            />
                            <button
                              type="button"
                              class="relative -ml-px inline-flex items-center rounded-r-md border border-gray-300 bg-gray-50 px-2 py-1 text-sm text-gray-700 hover:bg-gray-100"
                              phx-click="open_product_search"
                              phx-value-index={index}
                            >
                              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                              </svg>
                            </button>
                          </div>
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="text"
                            name={"lines[#{index}][reason]"}
                            value={line.reason}
                            placeholder={reason_placeholder(@adjustment_type)}
                            class="block w-full border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            name={"lines[#{index}][quantity]"}
                            value={line.quantity}
                            step="0.001"
                            min="0"
                            class="block w-24 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="text"
                            name={"lines[#{index}][unit]"}
                            value={line.unit}
                            class="block w-16 text-center border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            name={"lines[#{index}][unit_cost]"}
                            value={line.unit_cost}
                            step="0.01"
                            min="0"
                            class="block w-28 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </td>
                        <td class={"px-3 py-2 text-right font-medium text-#{@config.color}-600"}>
                          <%= if @config.direction == :decrease, do: "-" %><%= calculate_line_total(line) %> лв.
                        </td>
                        <td class="px-3 py-2 text-right">
                          <button
                            type="button"
                            phx-click="remove_line"
                            phx-value-index={index}
                            class="text-red-600 hover:text-red-900"
                          >
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>

                <%= if @lines == [] do %>
                  <div class="text-center py-12 text-sm text-gray-500">
                    <%= render_empty_icon(@adjustment_type) %>
                    <p class="mt-2"><%= empty_message(@adjustment_type) %></p>
                    <p class="text-xs text-gray-400">Натиснете "Добави ред" за да добавите артикули</p>
                  </div>
                <% end %>
              </div>

              <!-- Обобщение -->
              <%= if @lines != [] do %>
                <div class="mt-6 flex justify-end">
                  <div class={"w-72 space-y-2 bg-#{@config.color}-50 rounded-lg p-4 border border-#{@config.color}-200"}>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Брой позиции:</span>
                      <span class="font-medium"><%= length(@lines) %></span>
                    </div>
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Общо количество:</span>
                      <span class="font-medium"><%= calculate_total_quantity(@lines) %></span>
                    </div>
                    <div class={"flex justify-between text-base font-semibold border-t border-#{@config.color}-200 pt-2"}>
                      <span><%= if @config.direction == :decrease, do: "Загуба:", else: "Печалба:" %></span>
                      <span class={"text-#{@config.color}-600"}>
                        <%= if @config.direction == :decrease, do: "-" %><%= calculate_total(@lines) %> лв.
                      </span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Забележки -->
            <div class="mt-6">
              <label class="block text-sm font-medium text-gray-700">
                Забележки
              </label>
              <textarea
                name="adjustment[notes]"
                rows="3"
                placeholder="Допълнителна информация, обстоятелства..."
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              ></textarea>
            </div>

            <!-- Бутони -->
            <div class="mt-8 flex items-center justify-end gap-x-4 border-t border-gray-200 pt-6">
              <.link
                navigate={~p"/warehouse"}
                class="text-sm font-semibold leading-6 text-gray-900 hover:text-gray-700"
              >
                Отказ
              </.link>
              <button
                type="submit"
                class={"rounded-md bg-#{@config.color}-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-#{@config.color}-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-#{@config.color}-600"}
              >
                Запази документа
              </button>
            </div>
          </form>
        </div>
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
    </div>
    """
  end

  # Helper functions

  defp generate_document_no(prefix) do
    "#{prefix}-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"
  end

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_number(value) when is_number(value), do: value
  defp parse_number(_), do: 0

  defp calculate_line_total(line) do
    qty = parse_number(line.quantity)
    cost = parse_number(line.unit_cost)
    (qty * cost) |> Float.round(2) |> :erlang.float_to_binary(decimals: 2)
  end

  defp calculate_total_quantity(lines) do
    lines
    |> Enum.reduce(0, fn line, acc -> acc + parse_number(line.quantity) end)
    |> Float.round(3)
  end

  defp calculate_total(lines) do
    lines
    |> Enum.reduce(0, fn line, acc ->
      qty = parse_number(line.quantity)
      cost = parse_number(line.unit_cost)
      acc + qty * cost
    end)
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
  end

  defp reason_placeholder("scrap"), do: "Причина за брак (дефект, повреда...)"
  defp reason_placeholder("shortage"), do: "Причина за липсата..."
  defp reason_placeholder("surplus"), do: "Причина за излишъка..."
  defp reason_placeholder(_), do: "Причина..."

  defp empty_message("scrap"), do: "Няма добавени артикули за бракуване"
  defp empty_message("shortage"), do: "Няма добавени липсващи артикули"
  defp empty_message("surplus"), do: "Няма добавени излишни артикули"
  defp empty_message(_), do: "Няма добавени артикули"

  defp render_icon("trash", color) do
    assigns = %{color: color}
    ~H"""
    <div class={"flex items-center justify-center w-12 h-12 bg-#{@color}-100 rounded-lg"}>
      <svg class={"h-6 w-6 text-#{@color}-600"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
      </svg>
    </div>
    """
  end

  defp render_icon("exclamation-triangle", color) do
    assigns = %{color: color}
    ~H"""
    <div class={"flex items-center justify-center w-12 h-12 bg-#{@color}-100 rounded-lg"}>
      <svg class={"h-6 w-6 text-#{@color}-600"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
      </svg>
    </div>
    """
  end

  defp render_icon("plus-circle", color) do
    assigns = %{color: color}
    ~H"""
    <div class={"flex items-center justify-center w-12 h-12 bg-#{@color}-100 rounded-lg"}>
      <svg class={"h-6 w-6 text-#{@color}-600"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    </div>
    """
  end

  defp render_icon(_, _), do: nil

  defp render_empty_icon("scrap") do
    assigns = %{}
    ~H"""
    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
    </svg>
    """
  end

  defp render_empty_icon("shortage") do
    assigns = %{}
    ~H"""
    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
    </svg>
    """
  end

  defp render_empty_icon("surplus") do
    assigns = %{}
    ~H"""
    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  defp render_empty_icon(_), do: nil
end
