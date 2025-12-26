defmodule CyberWeb.StockLevelLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory

  def mount(_params, _session, socket) do
    stock_levels = Inventory.list_stock_levels(1)

    {:ok,
     socket
     |> assign(:page_title, "Складови наличности")
     |> assign(:stock_levels, stock_levels)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
      <p class="mt-2 text-sm text-gray-700">
        Преглед на текущите наличности по складове.
      </p>

      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Склад</th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Продукт</th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">Количество</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for level <- @stock_levels do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= level.warehouse.name %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= level.product.name %></td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 text-right"><%= level.quantity_on_hand %></td>
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
