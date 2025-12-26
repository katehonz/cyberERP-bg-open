defmodule CyberWeb.TrialBalanceLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting

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
      |> assign(:page_title, "Оборотна ведомост")
      |> load_trial_balance()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"from_date" => from_str, "to_date" => to_str}, socket) do
    with {:ok, from_date} <- Date.from_iso8601(from_str),
         {:ok, to_date} <- Date.from_iso8601(to_str) do
      socket =
        socket
        |> assign(:from_date, from_date)
        |> assign(:to_date, to_date)
        |> load_trial_balance()

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Невалидна дата")}
    end
  end

  @impl true
  def handle_event("current_month", _params, socket) do
    today = Date.utc_today()

    socket =
      socket
      |> assign(:from_date, Date.beginning_of_month(today))
      |> assign(:to_date, Date.end_of_month(today))
      |> load_trial_balance()

    {:noreply, socket}
  end

  @impl true
  def handle_event("current_year", _params, socket) do
    today = Date.utc_today()

    socket =
      socket
      |> assign(:from_date, Date.new!(today.year, 1, 1))
      |> assign(:to_date, Date.new!(today.year, 12, 31))
      |> load_trial_balance()

    {:noreply, socket}
  end

  defp load_trial_balance(socket) do
    trial_balance =
      Accounting.trial_balance(
        socket.assigns.tenant_id,
        socket.assigns.from_date,
        socket.assigns.to_date
      )

    # Calculate totals
    totals =
      trial_balance
      |> Enum.reduce(
        %{
          opening: Decimal.new(0),
          debit: Decimal.new(0),
          credit: Decimal.new(0),
          closing: Decimal.new(0)
        },
        fn row, acc ->
          %{
            opening: Decimal.add(acc.opening, Decimal.abs(row.opening_balance)),
            debit: Decimal.add(acc.debit, row.debit_turnover),
            credit: Decimal.add(acc.credit, row.credit_turnover),
            closing: Decimal.add(acc.closing, Decimal.abs(row.closing_balance))
          }
        end
      )

    socket
    |> assign(:trial_balance, trial_balance)
    |> assign(:totals, totals)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%d.%m.%Y")
  end

  defp format_amount(amount) do
    Decimal.to_string(amount, :normal)
  end

  defp format_balance(amount) do
    cond do
      Decimal.gt?(amount, 0) -> {"Дт", format_amount(amount), "text-blue-900"}
      Decimal.lt?(amount, 0) -> {"Кт", format_amount(Decimal.abs(amount)), "text-green-900"}
      true -> {"-", "0.00", "text-gray-500"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Оборотна ведомост</h1>
          <p class="mt-2 text-sm text-gray-700">
            Период: <%= format_date(@from_date) %> - <%= format_date(@to_date) %>
          </p>
        </div>
      </div>

      <div class="mt-4 flex items-center space-x-4">
        <div class="flex items-center space-x-2">
          <label class="text-sm font-medium text-gray-700">От:</label>
          <input
            type="date"
            name="from_date"
            value={Date.to_iso8601(@from_date)}
            phx-change="change_period"
            phx-value-to_date={Date.to_iso8601(@to_date)}
            class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>

        <div class="flex items-center space-x-2">
          <label class="text-sm font-medium text-gray-700">До:</label>
          <input
            type="date"
            name="to_date"
            value={Date.to_iso8601(@to_date)}
            phx-change="change_period"
            phx-value-from_date={Date.to_iso8601(@from_date)}
            class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
        </div>

        <button
          type="button"
          phx-click="current_month"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Текущ месец
        </button>

        <button
          type="button"
          phx-click="current_year"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Текуща година
        </button>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Сметка
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Наименование
                    </th>
                    <th
                      scope="col"
                      colspan="2"
                      class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900 bg-blue-50"
                    >
                      Начално салдо
                    </th>
                    <th
                      scope="col"
                      colspan="2"
                      class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900"
                    >
                      Обороти
                    </th>
                    <th
                      scope="col"
                      colspan="2"
                      class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900 bg-green-50"
                    >
                      Крайно салдо
                    </th>
                  </tr>
                  <tr class="border-t border-gray-200">
                    <th colspan="2"></th>
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
                  <%= for row <- @trial_balance do %>
                    <% {open_side, open_amt, open_class} = format_balance(row.opening_balance) %>
                    <% {close_side, close_amt, close_class} = format_balance(row.closing_balance) %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= row.account.code %>
                      </td>
                      <td class="px-3 py-4 text-sm text-gray-500">
                        <%= row.account.name %>
                      </td>
                      <!-- Начално Дт -->
                      <td class={[
                        "whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-blue-50",
                        open_class
                      ]}>
                        <%= if open_side == "Дт", do: open_amt, else: "-" %>
                      </td>
                      <!-- Начално Кт -->
                      <td class={[
                        "whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-blue-50",
                        open_class
                      ]}>
                        <%= if open_side == "Кт", do: open_amt, else: "-" %>
                      </td>
                      <!-- Дебитен оборот -->
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(row.debit_turnover) %>
                      </td>
                      <!-- Кредитен оборот -->
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(row.credit_turnover) %>
                      </td>
                      <!-- Крайно Дт -->
                      <td class={[
                        "whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-green-50",
                        close_class
                      ]}>
                        <%= if close_side == "Дт", do: close_amt, else: "-" %>
                      </td>
                      <!-- Крайно Кт -->
                      <td class={[
                        "whitespace-nowrap px-3 py-4 text-sm text-right font-mono bg-green-50",
                        close_class
                      ]}>
                        <%= if close_side == "Кт", do: close_amt, else: "-" %>
                      </td>
                    </tr>
                  <% end %>

                  <!-- Totals row -->
                  <tr class="bg-gray-100 font-semibold">
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
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8 rounded-lg bg-blue-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <h3 class="text-sm font-medium text-blue-800">Забележка</h3>
            <div class="mt-2 text-sm text-blue-700">
              <p>
                Оборотната ведомост показва начални салда, обороти за периода и крайни салда за всички сметки.
                Дебит (Дт) и Кредит (Кт) трябва винаги да са равни.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
