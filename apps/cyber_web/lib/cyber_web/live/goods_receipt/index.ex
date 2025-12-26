defmodule CyberWeb.GoodsReceiptLive.Index do
  use CyberWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Приемателни протоколи")
     |> assign(:goods_receipts, [])}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички приемателни протоколи.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/goods-receipts/new"}
            class="inline-flex items-center justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Нов протокол
          </.link>
        </div>
      </div>
      <!-- Table will go here -->
    </div>
    """
  end
end
