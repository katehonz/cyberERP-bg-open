defmodule CyberWeb.ReportsLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting
  alias CyberCore.Accounting.Reports
  alias Decimal, as: D

  @impl true
  def mount(_params, _session, socket) do
    # TODO: Get from session
    tenant_id = 1
    today = Date.utc_today()

    # Default: текущ месец
    from_date = Date.beginning_of_month(today)
    to_date = Date.end_of_month(today)

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:from_date, from_date)
      |> assign(:to_date, to_date)
      |> assign(:report_type, "trial_balance")
      |> assign(:account_id, nil)
      |> assign(:show_zero_balances, false)
      |> assign(:account_depth, nil)
      |> assign(:loading, false)
      |> assign(:page_title, "Счетоводни отчети")
      |> load_accounts()
      |> load_report()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_report_type", %{"type" => type}, socket) do
    socket =
      socket
      |> assign(:report_type, type)
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_period", %{"from_date" => from_str, "to_date" => to_str}, socket) do
    with {:ok, from_date} <- Date.from_iso8601(from_str),
         {:ok, to_date} <- Date.from_iso8601(to_str) do
      socket =
        socket
        |> assign(:from_date, from_date)
        |> assign(:to_date, to_date)
        |> load_report()

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Невалидна дата")}
    end
  end

  @impl true
  def handle_event("change_account", %{"account_id" => ""}, socket) do
    socket =
      socket
      |> assign(:account_id, nil)
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_account", %{"account_id" => account_id}, socket) do
    socket =
      socket
      |> assign(:account_id, String.to_integer(account_id))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_zero_balances", _params, socket) do
    socket =
      socket
      |> assign(:show_zero_balances, !socket.assigns.show_zero_balances)
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_depth", %{"depth" => ""}, socket) do
    socket =
      socket
      |> assign(:account_depth, nil)
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_depth", %{"depth" => depth}, socket) do
    socket =
      socket
      |> assign(:account_depth, String.to_integer(depth))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_period", %{"period" => "current_month"}, socket) do
    today = Date.utc_today()

    socket =
      socket
      |> assign(:from_date, Date.beginning_of_month(today))
      |> assign(:to_date, Date.end_of_month(today))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_period", %{"period" => "current_year"}, socket) do
    today = Date.utc_today()

    socket =
      socket
      |> assign(:from_date, Date.new!(today.year, 1, 1))
      |> assign(:to_date, Date.new!(today.year, 12, 31))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_period", %{"period" => "last_month"}, socket) do
    last_month = Date.utc_today() |> Date.add(-30)

    socket =
      socket
      |> assign(:from_date, Date.beginning_of_month(last_month))
      |> assign(:to_date, Date.end_of_month(last_month))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_period", %{"period" => "last_year"}, socket) do
    today = Date.utc_today()
    last_year = today.year - 1

    socket =
      socket
      |> assign(:from_date, Date.new!(last_year, 1, 1))
      |> assign(:to_date, Date.new!(last_year, 12, 31))
      |> load_report()

    {:noreply, socket}
  end

  @impl true
  def handle_event("export_excel", _params, socket) do
    # TODO: Implement Excel export
    {:noreply, put_flash(socket, :info, "Excel експортът ще бъде имплементиран скоро")}
  end

  @impl true
  def handle_event("export_pdf", _params, socket) do
    # TODO: Implement PDF export
    {:noreply, put_flash(socket, :info, "PDF експортът ще бъде имплементиран скоро")}
  end

  defp load_accounts(socket) do
    accounts = Accounting.list_accounts(socket.assigns.tenant_id)
    assign(socket, :accounts, accounts)
  end

  defp load_report(socket) do
    %{
      tenant_id: tenant_id,
      from_date: from_date,
      to_date: to_date,
      report_type: report_type,
      account_id: account_id,
      show_zero_balances: show_zero_balances,
      account_depth: account_depth
    } = socket.assigns

    opts = [
      account_id: account_id,
      show_zero_balances: show_zero_balances,
      account_depth: account_depth
    ]

    {report_data, totals} =
      case report_type do
        "trial_balance" ->
          data = Accounting.trial_balance(tenant_id, from_date, to_date)
          filtered_data = filter_trial_balance(data, opts)
          totals = calculate_trial_balance_totals(filtered_data)
          {filtered_data, totals}

        "transaction_log" ->
          data = Reports.transaction_log(tenant_id, from_date, to_date, opts)
          {data, nil}

        "general_ledger" ->
          data = Reports.general_ledger(tenant_id, from_date, to_date, opts)
          {data, nil}

        "chronological" ->
          data = Reports.chronological_report(tenant_id, from_date, to_date, opts)
          {data.entries, %{total_amount: data.total_amount}}

        "bg_general_ledger" ->
          data = Reports.bg_general_ledger(tenant_id, from_date, to_date, opts)
          {data, nil}

        _ ->
          {[], nil}
      end

    socket
    |> assign(:report_data, report_data)
    |> assign(:totals, totals)
  end

  defp filter_trial_balance(data, opts) do
    show_zero = Keyword.get(opts, :show_zero_balances, false)
    depth = Keyword.get(opts, :account_depth)

    data
    |> maybe_filter_by_depth(depth)
    |> maybe_filter_zero_balances(show_zero)
  end

  defp maybe_filter_by_depth(data, nil), do: data

  defp maybe_filter_by_depth(data, depth) do
    Enum.filter(data, fn row ->
      String.length(row.account.code) == depth
    end)
  end

  defp maybe_filter_zero_balances(data, true), do: data

  defp maybe_filter_zero_balances(data, false) do
    Enum.filter(data, fn row ->
      !D.equal?(row.opening_balance, D.new(0)) or
        !D.equal?(row.debit_turnover, D.new(0)) or
        !D.equal?(row.credit_turnover, D.new(0)) or
        !D.equal?(row.closing_balance, D.new(0))
    end)
  end

  defp calculate_trial_balance_totals(data) do
    data
    |> Enum.reduce(
      %{
        opening: D.new(0),
        debit: D.new(0),
        credit: D.new(0),
        closing: D.new(0)
      },
      fn row, acc ->
        %{
          opening: D.add(acc.opening, D.abs(row.opening_balance)),
          debit: D.add(acc.debit, row.debit_turnover),
          credit: D.add(acc.credit, row.credit_turnover),
          closing: D.add(acc.closing, D.abs(row.closing_balance))
        }
      end
    )
  end

  defp format_date(date) do
    Calendar.strftime(date, "%d.%m.%Y")
  end

  defp format_amount(amount) when is_nil(amount), do: "0.00"

  defp format_amount(amount) do
    amount
    |> D.round(2)
    |> D.to_string(:normal)
  end

  defp format_balance(amount) do
    cond do
      D.gt?(amount, 0) -> {"Дт", format_amount(amount), "text-blue-900 font-medium"}
      D.lt?(amount, 0) -> {"Кт", format_amount(D.abs(amount)), "text-green-900 font-medium"}
      true -> {"-", "0.00", "text-gray-400"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Счетоводни отчети</h1>
          <p class="mt-2 text-sm text-gray-600">
            Интелигентни отчети и анализи
          </p>
        </div>
      </div>

      <!-- Report Type Tabs -->
      <div class="border-b border-gray-200 mb-6">
        <nav class="-mb-px flex space-x-8">
          <button
            phx-click="change_report_type"
            phx-value-type="trial_balance"
            class={[
              "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@report_type == "trial_balance",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Оборотна ведомост
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="transaction_log"
            class={[
              "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@report_type == "transaction_log",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Дневник
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="general_ledger"
            class={[
              "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@report_type == "general_ledger",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Главна книга
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="chronological"
            class={[
              "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@report_type == "chronological",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Хронологичен
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="bg_general_ledger"
            class={[
              "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@report_type == "bg_general_ledger",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Главна книга (БГ)
          </button>
        </nav>
      </div>

      <!-- Filters -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
          <!-- Date Range -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">От дата</label>
            <input
              type="date"
              value={Date.to_iso8601(@from_date)}
              phx-change="change_period"
              phx-value-to_date={Date.to_iso8601(@to_date)}
              name="from_date"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">До дата</label>
            <input
              type="date"
              value={Date.to_iso8601(@to_date)}
              phx-change="change_period"
              phx-value-from_date={Date.to_iso8601(@from_date)}
              name="to_date"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <!-- Account Filter -->
          <%= if @report_type in ["trial_balance", "transaction_log", "general_ledger"] do %>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Сметка</label>
              <select
                phx-change="change_account"
                name="account_id"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Всички сметки</option>
                <%= for account <- @accounts do %>
                  <option value={account.id} selected={@account_id == account.id}>
                    <%= account.code %> - <%= account.name %>
                  </option>
                <% end %>
              </select>
            </div>
          <% end %>

          <!-- Account Depth -->
          <%= if @report_type == "trial_balance" do %>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Дълбочина</label>
              <select
                phx-change="change_depth"
                name="depth"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Всички нива</option>
                <option value="3" selected={@account_depth == 3}>3 цифри</option>
                <option value="4" selected={@account_depth == 4}>4 цифри</option>
                <option value="5" selected={@account_depth == 5}>5 цифри</option>
                <option value="6" selected={@account_depth == 6}>6 цифри</option>
              </select>
            </div>
          <% end %>
        </div>

        <!-- Quick Period Buttons -->
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span class="text-sm font-medium text-gray-700">Бърз избор:</span>
          <button
            phx-click="quick_period"
            phx-value-period="current_month"
            class="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Текущ месец
          </button>

          <button
            phx-click="quick_period"
            phx-value-period="last_month"
            class="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Предходен месец
          </button>

          <button
            phx-click="quick_period"
            phx-value-period="current_year"
            class="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Текуща година
          </button>

          <button
            phx-click="quick_period"
            phx-value-period="last_year"
            class="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Предходна година
          </button>
        </div>

        <!-- Additional Options -->
        <div class="flex items-center gap-4">
          <%= if @report_type == "trial_balance" do %>
            <label class="flex items-center">
              <input
                type="checkbox"
                phx-click="toggle_zero_balances"
                checked={@show_zero_balances}
                class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              />
              <span class="ml-2 text-sm text-gray-700">Показвай нулеви салда</span>
            </label>
          <% end %>

          <!-- Export Buttons -->
          <div class="ml-auto flex gap-2">
            <button
              phx-click="export_excel"
              class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <svg class="-ml-1 mr-2 h-5 w-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
              Excel
            </button>

            <button
              phx-click="export_pdf"
              class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <svg class="-ml-1 mr-2 h-5 w-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"
                />
              </svg>
              PDF
            </button>
          </div>
        </div>
      </div>

      <!-- Report Content -->
      <%= case @report_type do %>
        <% "trial_balance" -> %>
          <%= render_trial_balance(assigns) %>
        <% "transaction_log" -> %>
          <%= render_transaction_log(assigns) %>
        <% "general_ledger" -> %>
          <%= render_general_ledger(assigns) %>
        <% "chronological" -> %>
          <%= render_chronological(assigns) %>
        <% "bg_general_ledger" -> %>
          <%= render_bg_general_ledger(assigns) %>
        <% _ -> %>
          <div class="text-center py-12">
            <p class="text-gray-500">Изберете вид отчет</p>
          </div>
      <% end %>
    </div>
    """
  end

  # Trial Balance Render
  defp render_trial_balance(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200 bg-gradient-to-r from-indigo-500 to-purple-600">
        <h2 class="text-xl font-semibold text-white">Оборотна ведомост</h2>
        <p class="text-sm text-indigo-100 mt-1">
          Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
        </p>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th
                rowspan="2"
                class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
              >
                Сметка
              </th>
              <th
                rowspan="2"
                class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
              >
                Наименование
              </th>
              <th
                colspan="2"
                class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900 bg-blue-50"
              >
                Начално салдо
              </th>
              <th
                colspan="2"
                class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900"
              >
                Обороти
              </th>
              <th
                colspan="2"
                class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900 bg-green-50"
              >
                Крайно салдо
              </th>
            </tr>
            <tr class="border-t border-gray-200">
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 bg-blue-50">
                Дт
              </th>
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 bg-blue-50">
                Кт
              </th>
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500">Дебит</th>
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500">Кредит</th>
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 bg-green-50">
                Дт
              </th>
              <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 bg-green-50">
                Кт
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= for row <- @report_data do %>
              <% {open_side, open_amt, open_class} = format_balance(row.opening_balance) %>
              <% {close_side, close_amt, close_class} = format_balance(row.closing_balance) %>
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                  <%= row.account.code %>
                </td>
                <td class="px-3 py-4 text-sm text-gray-700">
                  <%= row.account.name %>
                </td>
                <!-- Opening Debit -->
                <td class={["whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-blue-50", open_class]}>
                  <%= if open_side == "Дт", do: open_amt, else: "-" %>
                </td>
                <!-- Opening Credit -->
                <td class={["whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-blue-50", open_class]}>
                  <%= if open_side == "Кт", do: open_amt, else: "-" %>
                </td>
                <!-- Debit Turnover -->
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                  <%= format_amount(row.debit_turnover) %>
                </td>
                <!-- Credit Turnover -->
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                  <%= format_amount(row.credit_turnover) %>
                </td>
                <!-- Closing Debit -->
                <td class={["whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-green-50", close_class]}>
                  <%= if close_side == "Дт", do: close_amt, else: "-" %>
                </td>
                <!-- Closing Credit -->
                <td class={["whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-green-50", close_class]}>
                  <%= if close_side == "Кт", do: close_amt, else: "-" %>
                </td>
              </tr>
            <% end %>

            <!-- Totals Row -->
            <%= if @totals do %>
              <tr class="bg-gradient-to-r from-gray-100 to-gray-50 font-bold border-t-2 border-gray-400">
                <td colspan="2" class="py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                  ОБЩО:
                </td>
                <td colspan="2" class="px-3 py-4 text-sm text-gray-900 text-right font-mono bg-blue-100">
                  <%= format_amount(@totals.opening) %>
                </td>
                <td class="px-3 py-4 text-sm text-gray-900 text-right font-mono">
                  <%= format_amount(@totals.debit) %>
                </td>
                <td class="px-3 py-4 text-sm text-gray-900 text-right font-mono">
                  <%= format_amount(@totals.credit) %>
                </td>
                <td colspan="2" class="px-3 py-4 text-sm text-gray-900 text-right font-mono bg-green-100">
                  <%= format_amount(@totals.closing) %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Transaction Log Render
  defp render_transaction_log(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200 bg-gradient-to-r from-blue-500 to-cyan-600">
        <h2 class="text-xl font-semibold text-white">Дневник на операциите</h2>
        <p class="text-sm text-blue-100 mt-1">
          Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
        </p>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Дата
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                № Запис
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Документ
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Сметка
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Описание
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Дебит
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Кредит
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Контрагент
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for entry <- @report_data do %>
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= format_date(entry.date) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  <%= entry.entry_number %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= entry.document_number || "-" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <div class="font-medium"><%= entry.account_code %></div>
                  <div class="text-gray-500 text-xs"><%= entry.account_name %></div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900 max-w-md truncate">
                  <%= entry.description %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono text-blue-900">
                  <%= if D.gt?(entry.debit_amount, D.new(0)), do: format_amount(entry.debit_amount), else: "-" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono text-green-900">
                  <%= if D.gt?(entry.credit_amount, D.new(0)), do: format_amount(entry.credit_amount), else: "-" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= entry.counterpart_name || "-" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # General Ledger Render
  defp render_general_ledger(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= for account <- @report_data do %>
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <div class="px-6 py-4 bg-gradient-to-r from-purple-500 to-pink-600 text-white">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="text-lg font-semibold">
                  <%= account.account_code %> - <%= account.account_name %>
                </h3>
              </div>
              <div class="flex gap-6 text-sm">
                <span>
                  Начално: <span class="font-bold"><%= format_amount(account.opening_balance) %></span>
                </span>
                <span>
                  Крайно: <span class="font-bold"><%= format_amount(account.closing_balance) %></span>
                </span>
              </div>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Дата
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    № Запис
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Документ
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Описание
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                    Дебит
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                    Кредит
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                    Салдо
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Контрагент
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <!-- Opening Balance -->
                <%= if !D.equal?(account.opening_balance, D.new(0)) do %>
                  <tr class="bg-blue-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= format_date(@from_date) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      Начално салдо
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">-</td>
                    <td class="px-6 py-4 text-sm text-gray-500">Салдо към началото на периода</td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono">
                      <%= if D.gt?(account.opening_balance, D.new(0)),
                        do: format_amount(account.opening_balance),
                        else: "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono">
                      <%= if D.lt?(account.opening_balance, D.new(0)),
                        do: format_amount(D.abs(account.opening_balance)),
                        else: "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono font-medium">
                      <%= format_amount(account.opening_balance) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">-</td>
                  </tr>
                <% end %>

                <!-- Entries -->
                <%= for entry <- account.entries do %>
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= format_date(entry.date) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= entry.entry_number %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= entry.document_number || "-" %>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900 max-w-md truncate">
                      <%= entry.description %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono text-blue-900">
                      <%= if D.gt?(entry.debit_amount, D.new(0)),
                        do: format_amount(entry.debit_amount),
                        else: "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono text-green-900">
                      <%= if D.gt?(entry.credit_amount, D.new(0)),
                        do: format_amount(entry.credit_amount),
                        else: "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono font-medium">
                      <%= format_amount(entry.balance) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= entry.counterpart_name || "-" %>
                    </td>
                  </tr>
                <% end %>

                <!-- Totals -->
                <tr class="bg-gray-100 font-semibold border-t-2">
                  <td colspan="4" class="px-6 py-4 text-sm text-gray-900">Общо за сметката:</td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono">
                    <%= format_amount(account.total_debits) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono">
                    <%= format_amount(account.total_credits) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-mono font-bold">
                    <%= format_amount(account.closing_balance) %>
                  </td>
                  <td></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Chronological Report Render
  defp render_chronological(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200 bg-gradient-to-r from-green-500 to-teal-600">
        <h2 class="text-xl font-semibold text-white">Хронологичен регистър</h2>
        <p class="text-sm text-green-100 mt-1">
          Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
        </p>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Дата</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Дебит</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Кредит</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Сума (BGN)</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Описание</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for entry <- @report_data do %>
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="px-4 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= format_date(entry.date) %>
                </td>
                <td class="px-4 py-4 text-sm text-gray-900">
                  <div class="font-medium text-blue-900"><%= entry.debit_account_code %></div>
                  <div class="text-gray-500 text-xs"><%= entry.debit_account_name %></div>
                </td>
                <td class="px-4 py-4 text-sm text-gray-900">
                  <div class="font-medium text-green-900"><%= entry.credit_account_code %></div>
                  <div class="text-gray-500 text-xs"><%= entry.credit_account_name %></div>
                </td>
                <td class="px-4 py-4 whitespace-nowrap text-sm text-right font-mono font-medium">
                  <%= format_amount(entry.amount) %>
                </td>
                <td class="px-4 py-4 text-sm text-gray-900 max-w-md truncate">
                  <%= entry.description %>
                </td>
              </tr>
            <% end %>

            <%= if @totals do %>
              <tr class="bg-gray-100 font-bold border-t-2">
                <td colspan="3" class="px-4 py-4 text-sm text-gray-900">ОБЩО:</td>
                <td class="px-4 py-4 whitespace-nowrap text-sm text-right font-mono">
                  <%= format_amount(@totals.total_amount) %>
                </td>
                <td></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # BG General Ledger Render
  defp render_bg_general_ledger(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- By Debit -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <div class="px-6 py-4 bg-gradient-to-r from-blue-600 to-blue-700 text-white">
          <h2 class="text-xl font-semibold">Главна книга по Дебит</h2>
          <p class="text-sm text-blue-100 mt-1">
            Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
          </p>
        </div>

        <%= for group <- @report_data.by_debit do %>
          <div class="border-b border-gray-200 last:border-b-0">
            <div class="bg-blue-50 px-6 py-3 flex justify-between items-center">
              <div class="font-semibold text-gray-900">
                <span class="text-blue-700"><%= group.debit_account_code %></span>
                - <%= group.debit_account_name %>
              </div>
              <div class="text-sm font-medium text-gray-600">
                Общо: <%= format_amount(group.total_amount) %> лв.
              </div>
            </div>
            <table class="min-w-full">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                    Кредит сметка
                  </th>
                  <th class="px-6 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                    Стойност
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <%= for entry <- group.entries do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-3 text-sm text-gray-900">
                      <span class="font-medium text-green-700"><%= entry.credit_account_code %></span>
                      - <%= entry.credit_account_name %>
                    </td>
                    <td class="px-6 py-3 whitespace-nowrap text-sm text-right font-mono">
                      <%= format_amount(entry.amount) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <!-- By Credit -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <div class="px-6 py-4 bg-gradient-to-r from-green-600 to-green-700 text-white">
          <h2 class="text-xl font-semibold">Главна книга по Кредит</h2>
          <p class="text-sm text-green-100 mt-1">
            Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
          </p>
        </div>

        <%= for group <- @report_data.by_credit do %>
          <div class="border-b border-gray-200 last:border-b-0">
            <div class="bg-green-50 px-6 py-3 flex justify-between items-center">
              <div class="font-semibold text-gray-900">
                <span class="text-green-700"><%= group.credit_account_code %></span>
                - <%= group.credit_account_name %>
              </div>
              <div class="text-sm font-medium text-gray-600">
                Общо: <%= format_amount(group.total_amount) %> лв.
              </div>
            </div>
            <table class="min-w-full">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                    Дебит сметка
                  </th>
                  <th class="px-6 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                    Стойност
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <%= for entry <- group.entries do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-3 text-sm text-gray-900">
                      <span class="font-medium text-blue-700"><%= entry.debit_account_code %></span>
                      - <%= entry.debit_account_name %>
                    </td>
                    <td class="px-6 py-3 whitespace-nowrap text-sm text-right font-mono">
                      <%= format_amount(entry.amount) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
