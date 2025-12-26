defmodule CyberWeb.StockMovementLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Inventory.StockMovement

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Складови движения")
     |> assign(:movements, [])
     |> load_movements()}
  end

  defp load_movements(socket) do
    # TODO: Fetch tenant_id from session
    movements = Inventory.list_stock_movements(1, preload: [:product, :warehouse, :to_warehouse])
    assign(socket, :movements, movements)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички складови движения.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <% # TODO: Add buttons for Goods Receipt, Issue, Transfer %>
        </div>
      </div>

      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Дата</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Тип</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Продукт</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">От склад</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">До склад</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Количество</th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Статус</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for movement <- @movements do %>
                    <tr id={"movement-#{movement.id}"}>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= movement.movement_date %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= movement.movement_type %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= movement.product.name %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= movement.warehouse.name %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if movement.to_warehouse, do: movement.to_warehouse.name, else: "-" %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= movement.quantity %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= movement.status %></td>
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
