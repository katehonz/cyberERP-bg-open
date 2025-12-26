defmodule CyberWeb.StockTransferLive.Index do
  use CyberWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Трансфер между складове")
     |> assign(:stock_transfers, [])}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички документи за трансфер.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/stock-transfers/new"}
            class="inline-flex items-center justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Нов трансфер
          </.link>
        </div>
      </div>
      <!-- Table will go here -->
    </div>
    """
  end
end
