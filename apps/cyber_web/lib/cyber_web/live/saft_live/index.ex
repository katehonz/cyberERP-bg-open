defmodule CyberWeb.SaftLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.SAFT

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = 1
    today = Date.utc_today()

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:page_title, "SAF-T Експорт")
      |> assign(:report_type, "monthly")
      |> assign(:year, today.year)
      |> assign(:month, today.month)
      |> assign(:start_date, Date.beginning_of_month(today))
      |> assign(:end_date, Date.end_of_month(today))
      |> assign(:generating, false)
      |> assign(:generated_file, nil)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_report_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :report_type, type)}
  end

  @impl true
  def handle_event("change_year", %{"year" => year}, socket) do
    year = String.to_integer(year)
    {:noreply, assign(socket, :year, year)}
  end

  @impl true
  def handle_event("change_month", %{"month" => month}, socket) do
    month = String.to_integer(month)
    {:noreply, assign(socket, :month, month)}
  end

  @impl true
  def handle_event("change_period", %{"start_date" => start_str, "end_date" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str) do
      socket =
        socket
        |> assign(:start_date, start_date)
        |> assign(:end_date, end_date)

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Невалидна дата")}
    end
  end

  @impl true
  def handle_event("generate", _params, socket) do
    socket = assign(socket, :generating, true)
    send(self(), :do_generate)
    {:noreply, socket}
  end

  @impl true
  def handle_event("download", _params, socket) do
    case socket.assigns.generated_file do
      %{content: content, filename: filename} ->
        {:noreply,
         push_event(socket, "download", %{
           content: Base.encode64(content),
           filename: filename,
           content_type: "application/xml"
         })}

      nil ->
        {:noreply, put_flash(socket, :error, "Няма генериран файл")}
    end
  end

  @impl true
  def handle_info(:do_generate, socket) do
    %{
      tenant_id: tenant_id,
      report_type: report_type,
      year: year,
      month: month,
      start_date: start_date,
      end_date: end_date
    } = socket.assigns

    result =
      case report_type do
        "monthly" ->
          SAFT.generate(:monthly, tenant_id, year: year, month: month)

        "annual" ->
          SAFT.generate(:annual, tenant_id, year: year)

        "on_demand" ->
          SAFT.generate(:on_demand, tenant_id, start_date: start_date, end_date: end_date)
      end

    socket =
      case result do
        {:ok, xml} ->
          filename = generate_filename(report_type, year, month)

          socket
          |> assign(:generating, false)
          |> assign(:generated_file, %{content: xml, filename: filename})
          |> assign(:error, nil)
          |> put_flash(:info, "SAF-T файлът е генериран успешно!")

        {:error, reason} ->
          socket
          |> assign(:generating, false)
          |> assign(:error, inspect(reason))
          |> put_flash(:error, "Грешка при генериране: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  defp generate_filename(report_type, year, month) do
    date_str = Date.utc_today() |> Date.to_iso8601()

    case report_type do
      "monthly" ->
        month_str = String.pad_leading(to_string(month), 2, "0")
        "SAFT_Monthly_#{year}_#{month_str}_#{date_str}.xml"

      "annual" ->
        "SAFT_Annual_#{year}_#{date_str}.xml"

      "on_demand" ->
        "SAFT_OnDemand_#{date_str}.xml"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8" id="saft-export" phx-hook="Download">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">SAF-T Експорт</h1>
          <p class="mt-2 text-sm text-gray-600">
            Стандартен одитен файл за данъчни цели (Standard Audit File for Tax)
          </p>
        </div>
      </div>

      <!-- Info Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div class="bg-blue-50 rounded-lg p-4 border border-blue-200">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-8 w-8 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <div class="ml-4">
              <h3 class="text-sm font-medium text-blue-900">Месечен отчет</h3>
              <p class="text-xs text-blue-700">MasterFiles + GeneralLedgerEntries + SourceDocuments</p>
            </div>
          </div>
        </div>

        <div class="bg-green-50 rounded-lg p-4 border border-green-200">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-8 w-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
            </div>
            <div class="ml-4">
              <h3 class="text-sm font-medium text-green-900">Годишен отчет</h3>
              <p class="text-xs text-green-700">Assets + AssetTransactions</p>
            </div>
          </div>
        </div>

        <div class="bg-purple-50 rounded-lg p-4 border border-purple-200">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-8 w-8 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <div class="ml-4">
              <h3 class="text-sm font-medium text-purple-900">При поискване</h3>
              <p class="text-xs text-purple-700">PhysicalStock + MovementOfGoods</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Report Type Selection -->
      <div class="bg-white rounded-lg shadow p-6 mb-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Вид на отчета</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <button
            phx-click="change_report_type"
            phx-value-type="monthly"
            class={[
              "p-4 rounded-lg border-2 text-left transition-all",
              if(@report_type == "monthly",
                do: "border-blue-500 bg-blue-50",
                else: "border-gray-200 hover:border-blue-300"
              )
            ]}
          >
            <div class="font-medium text-gray-900">Месечен</div>
            <div class="text-sm text-gray-500">Фактури, Плащания, Счетоводни записи</div>
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="annual"
            class={[
              "p-4 rounded-lg border-2 text-left transition-all",
              if(@report_type == "annual",
                do: "border-green-500 bg-green-50",
                else: "border-gray-200 hover:border-green-300"
              )
            ]}
          >
            <div class="font-medium text-gray-900">Годишен</div>
            <div class="text-sm text-gray-500">Дълготрайни активи и транзакции</div>
          </button>

          <button
            phx-click="change_report_type"
            phx-value-type="on_demand"
            class={[
              "p-4 rounded-lg border-2 text-left transition-all",
              if(@report_type == "on_demand",
                do: "border-purple-500 bg-purple-50",
                else: "border-gray-200 hover:border-purple-300"
              )
            ]}
          >
            <div class="font-medium text-gray-900">При поискване</div>
            <div class="text-sm text-gray-500">Складови наличности и движения</div>
          </button>
        </div>

        <!-- Period Selection -->
        <div class="border-t border-gray-200 pt-4">
          <h3 class="text-sm font-medium text-gray-700 mb-3">Период</h3>

          <%= if @report_type == "monthly" do %>
            <div class="grid grid-cols-2 gap-4 max-w-md">
              <div>
                <label class="block text-sm text-gray-600 mb-1">Година</label>
                <select
                  phx-change="change_year"
                  name="year"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                >
                  <%= for y <- (Date.utc_today().year - 5)..(Date.utc_today().year) do %>
                    <option value={y} selected={@year == y}><%= y %></option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Месец</label>
                <select
                  phx-change="change_month"
                  name="month"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                >
                  <%= for m <- 1..12 do %>
                    <option value={m} selected={@month == m}><%= month_name(m) %></option>
                  <% end %>
                </select>
              </div>
            </div>
          <% end %>

          <%= if @report_type == "annual" do %>
            <div class="max-w-xs">
              <label class="block text-sm text-gray-600 mb-1">Година</label>
              <select
                phx-change="change_year"
                name="year"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              >
                <%= for y <- (Date.utc_today().year - 5)..(Date.utc_today().year) do %>
                  <option value={y} selected={@year == y}><%= y %></option>
                <% end %>
              </select>
            </div>
          <% end %>

          <%= if @report_type == "on_demand" do %>
            <div class="grid grid-cols-2 gap-4 max-w-md">
              <div>
                <label class="block text-sm text-gray-600 mb-1">От дата</label>
                <input
                  type="date"
                  name="start_date"
                  value={Date.to_iso8601(@start_date)}
                  phx-change="change_period"
                  phx-value-end_date={Date.to_iso8601(@end_date)}
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">До дата</label>
                <input
                  type="date"
                  name="end_date"
                  value={Date.to_iso8601(@end_date)}
                  phx-change="change_period"
                  phx-value-start_date={Date.to_iso8601(@start_date)}
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>
            </div>
          <% end %>
        </div>

        <!-- Generate Button -->
        <div class="border-t border-gray-200 pt-4 mt-4">
          <button
            phx-click="generate"
            disabled={@generating}
            class={[
              "inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white transition-colors",
              if(@generating,
                do: "bg-gray-400 cursor-not-allowed",
                else: "bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              )
            ]}
          >
            <%= if @generating do %>
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Генериране...
            <% else %>
              <svg class="-ml-1 mr-3 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Генерирай SAF-T
            <% end %>
          </button>
        </div>
      </div>

      <!-- Generated File -->
      <%= if @generated_file do %>
        <div class="bg-green-50 rounded-lg shadow p-6 border border-green-200">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <svg class="h-10 w-10 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div class="ml-4">
                <h3 class="text-lg font-medium text-green-900">Файлът е готов!</h3>
                <p class="text-sm text-green-700"><%= @generated_file.filename %></p>
                <p class="text-xs text-green-600">
                  Размер: <%= Float.round(byte_size(@generated_file.content) / 1024, 2) %> KB
                </p>
              </div>
            </div>
            <button
              phx-click="download"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
            >
              <svg class="-ml-1 mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              Изтегли XML
            </button>
          </div>
        </div>
      <% end %>

      <!-- Error -->
      <%= if @error do %>
        <div class="bg-red-50 rounded-lg shadow p-6 border border-red-200 mt-6">
          <div class="flex items-center">
            <svg class="h-10 w-10 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="ml-4">
              <h3 class="text-lg font-medium text-red-900">Грешка при генериране</h3>
              <p class="text-sm text-red-700"><%= @error %></p>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Schema Info -->
      <div class="bg-gray-50 rounded-lg p-6 mt-6">
        <h3 class="text-sm font-medium text-gray-900 mb-2">Информация за схемата</h3>
        <dl class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <dt class="text-gray-500">Версия на схемата</dt>
            <dd class="font-medium text-gray-900">BG SAF-T Schema V 1.0.1</dd>
          </div>
          <div>
            <dt class="text-gray-500">Namespace</dt>
            <dd class="font-mono text-xs text-gray-900">mf:nra:dgti:dxxxx:declaration:v1</dd>
          </div>
          <div>
            <dt class="text-gray-500">Държава</dt>
            <dd class="font-medium text-gray-900">България (BG)</dd>
          </div>
          <div>
            <dt class="text-gray-500">Формат</dt>
            <dd class="font-medium text-gray-900">XML (UTF-8)</dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

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
end
