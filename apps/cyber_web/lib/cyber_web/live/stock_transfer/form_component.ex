defmodule CyberWeb.StockTransferLive.FormComponent do
  @moduledoc """
  Трансфер между складове - премества стока от един склад в друг.
  Създава двойка документи: предавателен (от склад) и приемателен (в склад).
  """
  use CyberWeb, :live_view

  alias Phoenix.LiveView.JS
  alias CyberCore.Inventory

  @impl true
  def mount(_params, _session, socket) do
    warehouses = Inventory.list_warehouses(1)

    {:ok,
     socket
     |> assign(:page_title, "Нов трансфер между складове")
     |> assign(:form, to_form(%{"document_no" => generate_document_no(), "document_date" => Date.utc_today()}))
     |> assign(:lines, [])
     |> assign(:warehouses, warehouses)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  @impl true
  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

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

  def handle_event("add_line", _, socket) do
    new_line = %{
      product: nil,
      product_id: nil,
      product_name: "",
      description: "",
      quantity: 1,
      unit: "бр."
    }

    {:noreply, assign(socket, :lines, socket.assigns.lines ++ [new_line])}
  end

  def handle_event("remove_line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    lines = List.delete_at(socket.assigns.lines, index)
    {:noreply, assign(socket, :lines, lines)}
  end

  def handle_event("validate", %{"stock_transfer" => _params, "lines" => lines_params}, socket) do
    lines =
      Enum.map(lines_params, fn {_index, line_map} ->
        existing_line = Enum.at(socket.assigns.lines, String.to_integer(_index)) || %{}

        %{
          product: Map.get(existing_line, :product),
          product_id: Map.get(existing_line, :product_id),
          product_name: Map.get(existing_line, :product_name, ""),
          description: Map.get(line_map, "description", ""),
          quantity: parse_number(Map.get(line_map, "quantity", "1")),
          unit: Map.get(line_map, "unit", "бр.")
        }
      end)

    {:noreply, assign(socket, :lines, lines)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"stock_transfer" => params, "lines" => lines_params}, socket) do
    lines =
      Enum.map(lines_params, fn {_i, line} ->
        %{
          "product_id" => line["product_id"],
          "quantity" => line["quantity"],
          "unit" => line["unit"]
        }
      end)

    attrs =
      params
      |> Map.put("tenant_id", 1)

    case Inventory.create_stock_transfer(attrs, lines) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Трансферът е създаден успешно.")
         |> push_navigate(to: ~p"/warehouse")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при създаване: #{inspect(reason)}")}
    end
  end

  def handle_event("save", _params, socket) do
    {:noreply, put_flash(socket, :error, "Моля добавете артикули към трансфера.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-2 text-sm text-gray-700">
            Преместване на стока между складове - създава предавателен и приемателен протокол
          </p>
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
        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 sm:rounded-xl">
          <form phx-change="validate" phx-submit="save" class="p-6">
            <!-- Хедър информация -->
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Номер на документ <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  name="stock_transfer[document_no]"
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
                  name="stock_transfer[document_date]"
                  value={@form[:document_date].value}
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>
            </div>

            <!-- Складове -->
            <div class="mt-6">
              <div class="bg-gradient-to-r from-red-50 via-gray-50 to-green-50 rounded-lg p-6">
                <div class="grid grid-cols-1 gap-6 sm:grid-cols-5 items-center">
                  <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-red-700">
                      ОТ Склад <span class="text-red-500">*</span>
                    </label>
                    <select
                      name="stock_transfer[from_warehouse_id]"
                      required
                      class="mt-1 block w-full rounded-md border-red-300 shadow-sm focus:border-red-500 focus:ring-red-500 sm:text-sm bg-white"
                    >
                      <option value="">Изберете склад...</option>
                      <%= for warehouse <- @warehouses do %>
                        <option value={warehouse.id}><%= warehouse.name %></option>
                      <% end %>
                    </select>
                  </div>

                  <div class="flex justify-center">
                    <div class="flex items-center justify-center w-12 h-12 bg-white rounded-full shadow">
                      <svg class="w-6 h-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3" />
                      </svg>
                    </div>
                  </div>

                  <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-green-700">
                      КЪМ Склад <span class="text-red-500">*</span>
                    </label>
                    <select
                      name="stock_transfer[to_warehouse_id]"
                      required
                      class="mt-1 block w-full rounded-md border-green-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm bg-white"
                    >
                      <option value="">Изберете склад...</option>
                      <%= for warehouse <- @warehouses do %>
                        <option value={warehouse.id}><%= warehouse.name %></option>
                      <% end %>
                    </select>
                  </div>
                </div>
              </div>
            </div>

            <!-- Артикули -->
            <div class="mt-8 border-t border-gray-200 pt-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-base font-medium text-gray-900">Артикули за прехвърляне</h3>
                <button
                  type="button"
                  phx-click="add_line"
                  class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
                >
                  + Добави ред
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Продукт</th>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Описание</th>
                      <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Количество</th>
                      <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Мярка</th>
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
                            name={"lines[#{index}][description]"}
                            value={line.description}
                            placeholder="Описание..."
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
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                    </svg>
                    <p class="mt-2">Няма добавени артикули за трансфер</p>
                    <p class="text-xs text-gray-400">Натиснете "Добави ред" за да добавите артикули</p>
                  </div>
                <% end %>
              </div>

              <!-- Обобщение -->
              <%= if @lines != [] do %>
                <div class="mt-6 flex justify-end">
                  <div class="w-64 space-y-2 bg-gray-50 rounded-lg p-4">
                    <div class="flex justify-between text-sm">
                      <span class="text-gray-600">Брой артикули:</span>
                      <span class="font-medium"><%= length(@lines) %></span>
                    </div>
                    <div class="flex justify-between text-base font-semibold border-t border-gray-200 pt-2">
                      <span>Общо количество:</span>
                      <span class="text-indigo-600"><%= calculate_total_quantity(@lines) %></span>
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
                name="stock_transfer[notes]"
                rows="3"
                placeholder="Причина за трансфера, допълнителна информация..."
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
                class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Изпълни трансфер
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

  defp generate_document_no do
    "ТР-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"
  end

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_number(value) when is_number(value), do: value
  defp parse_number(_), do: 0

  defp calculate_total_quantity(lines) do
    lines
    |> Enum.reduce(0, fn line, acc -> acc + parse_number(line.quantity) end)
    |> Float.round(3)
  end
end
