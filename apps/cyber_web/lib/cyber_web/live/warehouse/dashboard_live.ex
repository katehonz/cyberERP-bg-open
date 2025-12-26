defmodule CyberWeb.Warehouse.DashboardLive do
  use CyberWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Склад")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-semibold text-gray-900">Складово управление</h1>
      <p class="mt-2 text-sm text-gray-700">
        Управление на складови наличности, движения и документи.
      </p>

      <div class="mt-8 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
        <.link
          navigate={~p"/warehouses"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Складове</h3>
          <p class="mt-2 text-sm text-gray-600">Управление на физически складови локации.</p>
        </.link>

        <.link
          navigate={~p"/stock-levels"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Складови наличности</h3>
          <p class="mt-2 text-sm text-gray-600">Преглед на текущите наличности по складове.</p>
        </.link>

        <.link
          navigate={~p"/stock-movements"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Движения</h3>
          <p class="mt-2 text-sm text-gray-600">История на всички складови движения.</p>
        </.link>

        <.link
          navigate={~p"/goods-receipts/new"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Приемане на стока</h3>
          <p class="mt-2 text-sm text-gray-600">Създаване на Приемателен Протокол.</p>
        </.link>

        <.link
          navigate={~p"/goods-issues/new"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Издаване на стока</h3>
          <p class="mt-2 text-sm text-gray-600">Създаване на Предавателен Протокол.</p>
        </.link>

        <.link
          navigate={~p"/stock-transfers/new"}
          class="block rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-900/5 hover:bg-gray-50"
        >
          <h3 class="text-base font-semibold leading-6 text-gray-900">Вътрешен трансфер</h3>
          <p class="mt-2 text-sm text-gray-600">Прехвърляне на стока между складове.</p>
        </.link>
      </div>

      <!-- Инвентаризация и Корекции -->
      <h2 class="mt-12 text-lg font-semibold text-gray-900">Инвентаризация и Корекции</h2>
      <p class="mt-1 text-sm text-gray-600">Корекции на наличности след инвентаризация или при констатирани разлики.</p>

      <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <.link
          navigate={~p"/stock-adjustments/scrap"}
          class="block rounded-lg bg-red-50 p-6 shadow-sm ring-1 ring-red-200 hover:bg-red-100 transition-colors"
        >
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-red-100">
              <svg class="h-5 w-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </div>
            <div>
              <h3 class="text-base font-semibold leading-6 text-red-900">Брак</h3>
              <p class="text-xs text-red-700">Намалява наличност</p>
            </div>
          </div>
          <p class="mt-3 text-sm text-red-600">Бракуване на дефектни или повредени продукти.</p>
        </.link>

        <.link
          navigate={~p"/stock-adjustments/shortage"}
          class="block rounded-lg bg-orange-50 p-6 shadow-sm ring-1 ring-orange-200 hover:bg-orange-100 transition-colors"
        >
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-orange-100">
              <svg class="h-5 w-5 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <div>
              <h3 class="text-base font-semibold leading-6 text-orange-900">Липса</h3>
              <p class="text-xs text-orange-700">Намалява наличност</p>
            </div>
          </div>
          <p class="mt-3 text-sm text-orange-600">Регистриране на липсващи стоки след инвентаризация.</p>
        </.link>

        <.link
          navigate={~p"/stock-adjustments/surplus"}
          class="block rounded-lg bg-green-50 p-6 shadow-sm ring-1 ring-green-200 hover:bg-green-100 transition-colors"
        >
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-green-100">
              <svg class="h-5 w-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-base font-semibold leading-6 text-green-900">Излишък</h3>
              <p class="text-xs text-green-700">Увеличава наличност</p>
            </div>
          </div>
          <p class="mt-3 text-sm text-green-600">Регистриране на намерени свръхнормени количества.</p>
        </.link>

        <.link
          navigate={~p"/inventory-counts"}
          class="block rounded-lg bg-indigo-50 p-6 shadow-sm ring-1 ring-indigo-200 hover:bg-indigo-100 transition-colors"
        >
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-100">
              <svg class="h-5 w-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
              </svg>
            </div>
            <div>
              <h3 class="text-base font-semibold leading-6 text-indigo-900">Инвентаризация</h3>
              <p class="text-xs text-indigo-700">Преброяване</p>
            </div>
          </div>
          <p class="mt-3 text-sm text-indigo-600">Провеждане на инвентаризация и сравнение с наличности.</p>
        </.link>
      </div>
    </div>
    """
  end
end
