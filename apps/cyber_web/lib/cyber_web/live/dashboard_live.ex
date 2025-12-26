defmodule CyberWeb.DashboardLive do
  use CyberWeb, :live_view

  alias CyberCore.{Sales, Purchase, Bank, Inventory}
  alias CyberCore.Accounting.FixedAssets

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_stats)
    end

    {:ok,
     socket
     |> assign(:page_title, "Табло")
     |> assign(:loading, true)
     |> assign(:stats, %{})
     |> assign(:recent_invoices, [])
     |> assign(:recent_orders, [])
     |> assign(:low_stock, [])}
  end

  @impl true
  def handle_info(:load_stats, socket) do
    tenant_id = socket.assigns.current_tenant_id || 1

    # Зареждане на статистики с error handling
    stats = %{
      total_invoices: safe_count_invoices(tenant_id),
      issued_invoices: safe_count_invoices(tenant_id, "issued"),
      paid_invoices: safe_count_invoices(tenant_id, "paid"),
      overdue_invoices: safe_count_invoices(tenant_id, "overdue"),
      total_revenue: safe_calculate_revenue(tenant_id),
      pending_orders: safe_count_orders(tenant_id, "pending"),
      bank_balance: calculate_bank_balance(tenant_id),
      low_stock_count: count_low_stock(tenant_id),
      fixed_assets: safe_get_fixed_assets_stats(tenant_id)
    }

    # Последни фактури
    recent_invoices = safe_list_invoices(tenant_id) |> Enum.take(5)

    # Последни поръчки
    recent_orders = safe_list_orders(tenant_id) |> Enum.take(5)

    # Нисък stock
    low_stock = safe_list_low_stock(tenant_id) |> Enum.take(10)

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:stats, stats)
     |> assign(:recent_invoices, recent_invoices)
     |> assign(:recent_orders, recent_orders)
     |> assign(:low_stock, low_stock)}
  end

  defp safe_get_fixed_assets_stats(tenant_id) do
    try do
      FixedAssets.get_assets_statistics(tenant_id)
    rescue
      _ -> %{total_count: 0, total_book_value: Decimal.new(0)}
    end
  end

  defp safe_count_invoices(tenant_id, status \\ nil) do
    try do
      if status do
        count_invoices(tenant_id, status)
      else
        count_invoices(tenant_id)
      end
    rescue
      _ -> 0
    end
  end

  defp safe_calculate_revenue(tenant_id) do
    try do
      calculate_revenue(tenant_id)
    rescue
      _ -> Decimal.new(0)
    end
  end

  defp safe_count_orders(tenant_id, status) do
    try do
      count_orders(tenant_id, status)
    rescue
      _ -> 0
    end
  end

  defp safe_list_invoices(tenant_id) do
    try do
      Sales.list_invoices(tenant_id, [])
    rescue
      _ -> []
    end
  end

  defp safe_list_orders(tenant_id) do
    try do
      Purchase.list_purchase_orders(tenant_id, [])
    rescue
      _ -> []
    end
  end

  defp safe_list_low_stock(tenant_id) do
    try do
      Inventory.list_stock_levels(tenant_id, low_stock: true)
    rescue
      _ -> []
    end
  end

  defp count_invoices(tenant_id) do
    Sales.list_invoices(tenant_id, []) |> length()
  end

  defp count_invoices(tenant_id, status) do
    Sales.list_invoices(tenant_id, status: status) |> length()
  end

  defp calculate_revenue(tenant_id) do
    Sales.list_invoices(tenant_id, status: "paid")
    |> Enum.reduce(Decimal.new(0), fn invoice, acc ->
      Decimal.add(acc, invoice.total_amount)
    end)
  end

  defp count_orders(tenant_id, status) do
    Purchase.list_purchase_orders(tenant_id, status: status) |> length()
  end

  defp calculate_bank_balance(tenant_id) do
    try do
      Bank.list_bank_accounts(tenant_id, [])
      |> Enum.reduce(Decimal.new(0), fn account, acc ->
        Decimal.add(acc, account.current_balance)
      end)
    rescue
      _ -> Decimal.new(0)
    end
  end

  defp count_low_stock(tenant_id) do
    try do
      Inventory.list_stock_levels(tenant_id, low_stock: true) |> length()
    rescue
      _ -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-gray-900">Табло за управление</h1>
        <p class="mt-2 text-sm text-gray-700">
          Преглед на основните показатели и данни
        </p>
      </div>

      <%= if @loading do %>
        <div class="flex items-center justify-center h-64">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
        </div>
      <% else %>
        <!-- Stats Grid -->
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <!-- Общи фактури -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg
                    class="h-6 w-6 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Общо фактури
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= @stats.total_invoices %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-5 py-3">
              <div class="text-sm">
                <.link navigate={~p"/invoices"} class="font-medium text-indigo-600 hover:text-indigo-500">
                  Виж всички
                </.link>
              </div>
            </div>
          </div>
          <!-- Общи приходи -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg
                    class="h-6 w-6 text-green-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Общи приходи
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= Decimal.to_string(@stats.total_revenue, :normal) %> BGN
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-5 py-3">
              <div class="text-sm">
                <span class="text-gray-500"><%= @stats.paid_invoices %> платени фактури</span>
              </div>
            </div>
          </div>
          <!-- Банков баланс -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg
                    class="h-6 w-6 text-blue-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
                    />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Банков баланс
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= Decimal.to_string(@stats.bank_balance, :normal) %> BGN
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-5 py-3">
              <div class="text-sm">
                <.link
                  navigate={~p"/bank_accounts"}
                  class="font-medium text-indigo-600 hover:text-indigo-500"
                >
                  Виж сметките
                </.link>
              </div>
            </div>
          </div>
          <!-- Нисък stock -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg
                    class="h-6 w-6 text-yellow-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Нисък stock
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= @stats.low_stock_count %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-5 py-3">
              <div class="text-sm">
                <.link navigate={~p"/stock-levels"} class="font-medium text-indigo-600 hover:text-indigo-500">
                  Виж всички
                </.link>
              </div>
            </div>
          </div>

          <!-- Fixed Assets -->
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-6 w-6 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Дълготрайни активи
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= @stats.fixed_assets.total_count %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-5 py-3">
              <div class="text-sm">
                <.link navigate={~p"/fixed-assets"} class="font-medium text-indigo-600 hover:text-indigo-500">
                  Виж всички
                </.link>
              </div>
            </div>
          </div>
        </div>
        <!-- Recent Activity -->
        <div class="mt-8 grid grid-cols-1 gap-5 lg:grid-cols-2">
          <!-- Последни фактури -->
          <div class="bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Последни фактури</h3>
              <div class="flow-root">
                <ul role="list" class="-my-5 divide-y divide-gray-200">
                  <%= for invoice <- @recent_invoices do %>
                    <li class="py-4">
                      <div class="flex items-center space-x-4">
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate">
                            <%= invoice.invoice_no %>
                          </p>
                          <p class="text-sm text-gray-500 truncate">
                            <%= invoice.billing_name %>
                          </p>
                        </div>
                        <div class="text-right">
                          <p class="text-sm font-medium text-gray-900">
                            <%= Decimal.to_string(invoice.total_amount, :normal) %>
                            <%= invoice.currency %>
                          </p>
                          <p class="text-xs text-gray-500">
                            <%= Calendar.strftime(invoice.issue_date, "%d.%m.%Y") %>
                          </p>
                        </div>
                      </div>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
          <!-- Последни поръчки -->
          <div class="bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Последни поръчки</h3>
              <div class="flow-root">
                <ul role="list" class="-my-5 divide-y divide-gray-200">
                  <%= for order <- @recent_orders do %>
                    <li class="py-4">
                      <div class="flex items-center space-x-4">
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate">
                            <%= order.order_no %>
                          </p>
                          <p class="text-sm text-gray-500 truncate">
                            <%= order.supplier_name %>
                          </p>
                        </div>
                        <div class="text-right">
                          <p class="text-sm font-medium text-gray-900">
                            <%= Decimal.to_string(order.total_amount, :normal) %>
                            <%= order.currency %>
                          </p>
                          <p class="text-xs text-gray-500">
                            <%= Calendar.strftime(order.order_date, "%d.%m.%Y") %>
                          </p>
                        </div>
                      </div>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
