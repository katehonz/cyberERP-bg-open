defmodule CyberWeb.OssReportLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Sales

  @impl true
  def mount(_params, _session, socket) do
    report_data = Sales.get_oss_sales_report(1)

    {:ok,
     socket
     |> assign(:page_title, "OSS Справка по държави")
     |> assign(:report_data, report_data)
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)}
  end

  @impl true
  def handle_event("filter_dates", %{"from" => from, "to" => to}, socket) do
    {:noreply,
     socket
     |> assign(:date_from, from)
     |> assign(:date_to, to)
     |> load_report()}
  end

  defp load_report(socket) do
    opts = build_filter_opts(socket)
    report_data = Sales.get_oss_sales_report(1, opts)
    assign(socket, :report_data, report_data)
  end

  defp build_filter_opts(socket) do
    opts = []

    opts =
      if socket.assigns.date_from && socket.assigns.date_from != "" do
        [{:from, socket.assigns.date_from} | opts]
      else
        opts
      end

    opts =
      if socket.assigns.date_to && socket.assigns.date_to != "" do
        [{:to, socket.assigns.date_to} | opts]
      else
        opts
      end

    opts
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">OSS Справка</h1>
          <p class="mt-2 text-sm text-gray-700">
            Обобщена справка за продажбите в режим OSS по държави на потребление.
          </p>
        </div>
      </div>

      <!-- Филтри по период -->
      <div class="mt-6">
        <form phx-change="filter_dates" class="flex gap-4 items-end">
          <div>
            <label for="from" class="block text-sm font-medium text-gray-700">От дата</label>
            <input
              type="date"
              name="from"
              id="from"
              value={@date_from || ""}
              class="mt-1 block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
          <div>
            <label for="to" class="block text-sm font-medium text-gray-700">До дата</label>
            <input
              type="date"
              name="to"
              id="to"
              value={@date_to || ""}
              class="mt-1 block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </form>
      </div>

      <!-- Таблица -->
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Държава
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Нетна сума
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      ДДС
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for row <- @report_data do %>
                    <tr class="hover:bg-gray-50">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                        <div class="font-medium"><%= get_country_name(row.country_code) %></div>
                        <div class="text-gray-500 text-xs"><%= row.country_code %></div>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                        <%= Decimal.to_string(row.net_amount || Decimal.new(0), :normal) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                        <%= Decimal.to_string(row.tax_amount || Decimal.new(0), :normal) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if @report_data == [] do %>
                <div class="text-center py-12">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">Няма данни за OSS продажби</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Все още нямате издадени фактури в режим OSS.
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_country_name(code) do
    countries = %{
      "AT" => "Австрия",
      "BE" => "Белгия",
      "BG" => "България",
      "HR" => "Хърватия",
      "CY" => "Кипър",
      "CZ" => "Чехия",
      "DK" => "Дания",
      "EE" => "Естония",
      "FI" => "Финландия",
      "FR" => "Франция",
      "DE" => "Германия",
      "GR" => "Гърция",
      "HU" => "Унгария",
      "IE" => "Ирландия",
      "IT" => "Италия",
      "LV" => "Латвия",
      "LT" => "Литва",
      "LU" => "Люксембург",
      "MT" => "Малта",
      "NL" => "Нидерландия",
      "PL" => "Полша",
      "PT" => "Португалия",
      "RO" => "Румъния",
      "SK" => "Словакия",
      "SI" => "Словения",
      "ES" => "Испания",
      "SE" => "Швеция"
    }

    Map.get(countries, code, code)
  end
end
