defmodule CyberWeb.VatSalesRegisterLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting.Vat

  @impl true
  def mount(_params, _session, socket) do
    # TODO: Get from session
    tenant_id = 1
    today = Date.utc_today()

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:period_year, today.year)
      |> assign(:period_month, today.month)
      |> assign(:page_title, "Дневник продажби")
      |> load_entries()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"year" => year_str, "month" => month_str}, socket) do
    year = String.to_integer(year_str)
    month = String.to_integer(month_str)

    socket =
      socket
      |> assign(:period_year, year)
      |> assign(:period_month, month)
      |> load_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    {year, month} = previous_month(socket.assigns.period_year, socket.assigns.period_month)

    socket =
      socket
      |> assign(:period_year, year)
      |> assign(:period_month, month)
      |> load_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    {year, month} = next_month(socket.assigns.period_year, socket.assigns.period_month)

    socket =
      socket
      |> assign(:period_year, year)
      |> assign(:period_month, month)
      |> load_entries()

    {:noreply, socket}
  end

  defp load_entries(socket) do
    entries =
      Vat.list_sales_register(
        socket.assigns.tenant_id,
        socket.assigns.period_year,
        socket.assigns.period_month
      )

    # Calculate totals
    totals =
      Enum.reduce(
        entries,
        %{taxable: Decimal.new(0), vat: Decimal.new(0), total: Decimal.new(0)},
        fn entry, acc ->
          %{
            taxable: Decimal.add(acc.taxable, entry.taxable_base),
            vat: Decimal.add(acc.vat, entry.vat_amount),
            total: Decimal.add(acc.total, entry.total_amount)
          }
        end
      )

    socket
    |> assign(:entries, entries)
    |> assign(:totals, totals)
  end

  defp previous_month(year, 1), do: {year - 1, 12}
  defp previous_month(year, month), do: {year, month - 1}

  defp next_month(year, 12), do: {year + 1, 1}
  defp next_month(year, month), do: {year, month + 1}

  defp month_name(1), do: "Януари"
  defp month_name(2), do: "Февруари"
  defp month_name(3), do: "Март"
  defp month_name(4), do: "Април"
  defp month_name(5), do: "Май"
  defp month_name(6), do: "Юни"
  defp month_name(7), do: "Юли"
  defp month_name(8), do: "Август"
  defp month_name(9), do: "Септември"
  defp month_name(10), do: "Октомври"
  defp month_name(11), do: "Ноември"
  defp month_name(12), do: "Декември"

  defp format_date(nil), do: "-"
  defp format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp format_amount(nil), do: "0.00"
  defp format_amount(amount), do: Decimal.to_string(amount, :normal)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Дневник продажби</h1>
          <p class="mt-2 text-sm text-gray-700">
            Регистър на издадени данъчни документи според ЗДДС
          </p>
        </div>
      </div>

      <!-- Period selector -->
      <div class="mt-4 flex items-center space-x-4">
        <button
          type="button"
          phx-click="prev_month"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          ←
        </button>

        <div class="flex items-center space-x-2">
          <select
            phx-change="change_period"
            name="month"
            class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <%= for month <- 1..12 do %>
              <option value={month} selected={month == @period_month}>
                <%= month_name(month) %>
              </option>
            <% end %>
          </select>

          <select
            phx-change="change_period"
            name="year"
            class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <%= for year <- (@period_year - 2)..(@period_year + 1) do %>
              <option value={year} selected={year == @period_year}>
                <%= year %>
              </option>
            <% end %>
          </select>
        </div>

        <button
          type="button"
          phx-click="next_month"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          →
        </button>
      </div>

      <!-- Entries table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Дата док.
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Данъчно събитие
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Номер
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Получател
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Данъчна основа
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      ДДС
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Общо
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for entry <- @entries do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                        <%= format_date(entry.document_date) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= format_date(entry.tax_event_date) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                        <%= entry.document_number %>
                      </td>
                      <td class="px-3 py-4 text-sm text-gray-500">
                        <%= entry.recipient_name %>
                        <%= if entry.recipient_vat_number do %>
                          <br />
                          <span class="text-xs">ДДС: <%= entry.recipient_vat_number %></span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.taxable_base) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.vat_amount) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.total_amount) %>
                      </td>
                    </tr>
                  <% end %>

                  <%= if Enum.empty?(@entries) do %>
                    <tr>
                      <td colspan="7" class="py-8 text-center text-sm text-gray-500">
                        Няма записи за избрания период
                      </td>
                    </tr>
                  <% else %>
                    <!-- Totals row -->
                    <tr class="bg-gray-50 font-semibold">
                      <td colspan="4" class="py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                        ОБЩО:
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(@totals.taxable) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(@totals.vat) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(@totals.total) %>
                      </td>
                    </tr>
                  <% end %>
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
                Дневникът на продажбите се попълва автоматично при издаване на фактури.
                Записите се базират на данъчното събитие по ЗДДС.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
