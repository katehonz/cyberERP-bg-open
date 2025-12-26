defmodule CyberWeb.VatReturnLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting.{Vat, NapExport}

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
      |> assign(:page_title, "ДДС декларация")
      |> load_vat_return()

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
      |> load_vat_return()

    {:noreply, socket}
  end

  @impl true
  def handle_event("recalculate", _params, socket) do
    case Vat.recalculate_vat_return(
           socket.assigns.tenant_id,
           socket.assigns.period_year,
           socket.assigns.period_month
         ) do
      {:ok, _vat_return} ->
        socket =
          socket
          |> put_flash(:info, "ДДС декларацията е преизчислена успешно")
          |> load_vat_return()

        {:noreply, socket}

      {:error, :already_submitted} ->
        {:noreply, put_flash(socket, :error, "Не може да се редактира подадена декларация")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при преизчисление")}
    end
  end

  @impl true
  def handle_event("submit_return", _params, socket) do
    {:ok, vat_return} =
      Vat.get_or_create_vat_return(
        socket.assigns.tenant_id,
        socket.assigns.period_year,
        socket.assigns.period_month
      )

    case Vat.submit_vat_return(vat_return) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "ДДС декларацията е подадена")
          |> load_vat_return()

        {:noreply, socket}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, "Декларацията вече е подадена")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при подаване")}
    end
  end

  @impl true
  def handle_event("export_nap", _params, socket) do
    case NapExport.generate_nap_files(
           socket.assigns.tenant_id,
           socket.assigns.period_year,
           socket.assigns.period_month
         ) do
      {:ok, files} ->
        socket =
          socket
          |> put_flash(
            :info,
            "NAP файлове са генерирани успешно:\n#{files.deklar}\n#{files.pokupki}\n#{files.prodagbi}"
          )

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Грешка при генериране на NAP файлове: #{inspect(reason)}")}
    end
  end

  defp load_vat_return(socket) do
    {:ok, vat_return} =
      Vat.get_or_create_vat_return(
        socket.assigns.tenant_id,
        socket.assigns.period_year,
        socket.assigns.period_month
      )

    assign(socket, :vat_return, vat_return)
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

  defp format_date(nil), do: "-"
  defp format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp format_amount(nil), do: "0.00"
  defp format_amount(amount), do: Decimal.to_string(amount, :normal)

  defp status_badge("draft") do
    {" bg-yellow-100 text-yellow-800", "Чернова"}
  end

  defp status_badge("submitted") do
    {"bg-blue-100 text-blue-800", "Подадена"}
  end

  defp status_badge("accepted") do
    {"bg-green-100 text-green-800", "Приета"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">ДДС декларация</h1>
          <p class="mt-2 text-sm text-gray-700">
            Месечна справка за начислен и приспадащ се ДДС
          </p>
        </div>
      </div>

      <!-- Period selector -->
      <div class="mt-4 flex items-center justify-between">
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

          <% {badge_class, status_text} = status_badge(@vat_return.status) %>
          <span class={"inline-flex rounded-full px-3 py-1 text-xs font-semibold " <> badge_class}>
            <%= status_text %>
          </span>
        </div>

        <div class="flex items-center space-x-2">
          <!-- NAP Export button - always available -->
          <button
            type="button"
            phx-click="export_nap"
            class="rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-500"
          >
            Експорт NAP файлове
          </button>

          <%= if @vat_return.status == "draft" do %>
            <button
              type="button"
              phx-click="recalculate"
              class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            >
              Преизчисли
            </button>

            <button
              type="button"
              phx-click="submit_return"
              data-confirm="Сигурни ли сте, че искате да подадете декларацията?"
              class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              Подай декларация
            </button>
          <% end %>
        </div>
      </div>

      <!-- VAT Summary -->
      <div class="mt-8">
        <div class="overflow-hidden bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">
              Обобщение за <%= month_name(@period_month) %> <%= @period_year %>
            </h3>

            <dl class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
              <!-- Sales -->
              <div class="overflow-hidden rounded-lg bg-blue-50 px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Продажби (облагаема основа)</dt>
                <dd class="mt-1 text-2xl font-semibold tracking-tight text-gray-900">
                  <%= format_amount(@vat_return.total_sales_taxable) %> лв
                </dd>
              </div>

              <div class="overflow-hidden rounded-lg bg-blue-50 px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Начислен ДДС</dt>
                <dd class="mt-1 text-2xl font-semibold tracking-tight text-gray-900">
                  <%= format_amount(@vat_return.total_sales_vat) %> лв
                </dd>
              </div>

              <!-- Purchases -->
              <div class="overflow-hidden rounded-lg bg-green-50 px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Покупки (облагаема основа)</dt>
                <dd class="mt-1 text-2xl font-semibold tracking-tight text-gray-900">
                  <%= format_amount(@vat_return.total_purchases_taxable) %> лв
                </dd>
              </div>

              <div class="overflow-hidden rounded-lg bg-green-50 px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Приспадащ се ДДС</dt>
                <dd class="mt-1 text-2xl font-semibold tracking-tight text-gray-900">
                  <%= format_amount(@vat_return.total_deductible_vat) %> лв
                </dd>
              </div>
            </dl>

            <!-- Result -->
            <div class="mt-8 border-t border-gray-200 pt-6">
              <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <%= if Decimal.gt?(@vat_return.vat_payable, 0) do %>
                  <div class="overflow-hidden rounded-lg bg-red-50 px-4 py-5 shadow sm:p-6">
                    <dt class="text-sm font-medium text-gray-500">ДДС за внасяне</dt>
                    <dd class="mt-1 text-3xl font-bold tracking-tight text-red-900">
                      <%= format_amount(@vat_return.vat_payable) %> лв
                    </dd>
                    <%= if @vat_return.due_date do %>
                      <p class="mt-2 text-sm text-gray-600">
                        Падеж: <%= format_date(@vat_return.due_date) %>
                      </p>
                    <% end %>
                  </div>
                <% else %>
                  <div class="overflow-hidden rounded-lg bg-green-50 px-4 py-5 shadow sm:p-6">
                    <dt class="text-sm font-medium text-gray-500">ДДС за възстановяване</dt>
                    <dd class="mt-1 text-3xl font-bold tracking-tight text-green-900">
                      <%= format_amount(@vat_return.vat_refundable) %> лв
                    </dd>
                  </div>
                <% end %>

                <div class="overflow-hidden rounded-lg bg-gray-50 px-4 py-5 shadow sm:p-6">
                  <dt class="text-sm font-medium text-gray-500">Информация</dt>
                  <dd class="mt-2 space-y-1 text-sm text-gray-900">
                    <%= if @vat_return.submission_date do %>
                      <p>Подадена: <%= format_date(@vat_return.submission_date) %></p>
                    <% end %>
                    <%= if @vat_return.due_date do %>
                      <p>Падеж: <%= format_date(@vat_return.due_date) %></p>
                    <% end %>
                    <p>Статус: <%= elem(status_badge(@vat_return.status), 1) %></p>
                  </dd>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Links -->
      <div class="mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2">
        <.link
          navigate={~p"/vat/sales-register"}
          class="block rounded-lg bg-white px-4 py-5 shadow hover:bg-gray-50 sm:p-6"
        >
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg
                class="h-6 w-6 text-blue-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dt class="truncate text-sm font-medium text-gray-500">Дневник продажби</dt>
              <dd class="mt-1 text-lg font-semibold text-gray-900">Прегледай записи</dd>
            </div>
          </div>
        </.link>

        <.link
          navigate={~p"/vat/purchase-register"}
          class="block rounded-lg bg-white px-4 py-5 shadow hover:bg-gray-50 sm:p-6"
        >
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg
                class="h-6 w-6 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z"
                />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dt class="truncate text-sm font-medium text-gray-500">Дневник покупки</dt>
              <dd class="mt-1 text-lg font-semibold text-gray-900">Прегледай записи</dd>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
