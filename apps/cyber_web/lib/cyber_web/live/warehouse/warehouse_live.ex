defmodule CyberWeb.Warehouse.WarehouseLive do
  use CyberWeb, :live_view

  alias CyberCore.Inventory

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Складове")
     |> assign(:warehouses, [])
     |> assign(:show_modal, false)
     |> assign(:modal_payload, %{})
     |> load_warehouses()}
  end

  defp load_warehouses(socket) do
    assign(socket, :warehouses, Inventory.list_warehouses(1))
  end

  defp costing_method_label("weighted_average"), do: "Средно претеглена"
  defp costing_method_label("fifo"), do: "FIFO"
  defp costing_method_label("lifo"), do: "LIFO"
  defp costing_method_label(_), do: "Средно претеглена"

  def handle_event("show_modal", payload, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:modal_payload, Jason.decode!(payload))}
  end

  def handle_info({:hide_modal, _}, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_info({:warehouse_created, warehouse}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> put_flash(:info, "Складът е създаден успешно.")
     |> assign(:warehouses, [warehouse | socket.assigns.warehouses])}
  end

  def handle_info({:warehouse_updated, warehouse}, socket) do
    warehouses =
      Enum.map(socket.assigns.warehouses, fn
        %{id: id} when id == warehouse.id -> warehouse
        wh -> wh
      end)

    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> put_flash(:info, "Складът е обновен успешно.")
     |> assign(:warehouses, warehouses)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички складове.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button
            phx-click="show_modal"
            phx-value-payload={Jason.encode!(%{})}
            class="inline-flex items-center justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Нов склад
          </button>
        </div>
      </div>

      <%= if @show_modal do %>
        <.live_component
          module={CyberWeb.Warehouse.FormComponent}
          id="warehouse-form-modal"
          payload={@modal_payload}
          parent={self()}
        />
      <% end %>

      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Код</th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Име</th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Метод оценка</th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Активен</th>
                    <th class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Действия</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for warehouse <- @warehouses do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= warehouse.code %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= warehouse.name %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= costing_method_label(warehouse.costing_method) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if warehouse.is_active, do: "Да", else: "Не" %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <button
                          phx-click="show_modal"
                          phx-value-payload={Jason.encode!(%{warehouse: warehouse})}
                          class="text-indigo-600 hover:text-indigo-900"
                        >
                          Редактирай
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
