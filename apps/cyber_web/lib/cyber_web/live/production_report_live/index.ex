defmodule CyberWeb.ProductionReportLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Manufacturing

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    orders = Manufacturing.list_production_orders(@tenant_id)
    
    socket = 
      socket
      |> assign(:page_title, "Производствен отчет")
      |> assign(:orders, orders)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-semibold text-gray-900">Производствен отчет</h1>

      <table class="min-w-full divide-y divide-gray-300 mt-4">
        <thead class="bg-gray-50">
          <tr>
            <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Номер</th>
            <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Продукт</th>
            <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Количество</th>
            <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Статус</th>
            <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Планирана</th>
            <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Завършена</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200 bg-white">
          <%= for order <- @orders do %>
            <tr>
              <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= order.order_number %></td>
              <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.output_product && order.output_product.name %></td>
              <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.quantity_to_produce %></td>
              <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.status %></td>
              <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.planned_date %></td>
              <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.completion_date %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
