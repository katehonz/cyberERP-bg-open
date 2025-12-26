defmodule CyberWeb.VatPurchaseRegisterLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting.Vat
  alias CyberCore.Accounting.VatPurchaseRegister

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
      |> assign(:page_title, "Дневник покупки")
      |> assign(:show_form, false)
      |> assign(:entry, nil)
      |> load_entries()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Дневник покупки")
    |> assign(:show_form, false)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов запис в дневник покупки")
    |> assign(:show_form, true)
    |> assign(:entry, %VatPurchaseRegister{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    entry = Enum.find(socket.assigns.entries, &(&1.id == String.to_integer(id)))

    socket
    |> assign(:page_title, "Редактиране на запис")
    |> assign(:show_form, true)
    |> assign(:entry, entry)
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

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    entry = Enum.find(socket.assigns.entries, &(&1.id == String.to_integer(id)))

    case Vat.delete_purchase_register_entry(entry) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Записът е изтрит")
          |> load_entries()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при изтриване")}
    end
  end

  @impl true
  def handle_info({:entry_saved, message}, socket) do
    socket =
      socket
      |> put_flash(:info, message)
      |> push_navigate(to: ~p"/vat/purchase-register")
      |> load_entries()

    {:noreply, socket}
  end

  defp load_entries(socket) do
    entries =
      Vat.list_purchase_register(
        socket.assigns.tenant_id,
        socket.assigns.period_year,
        socket.assigns.period_month
      )

    assign(socket, :entries, entries)
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
          <h1 class="text-base font-semibold leading-6 text-gray-900">Дневник покупки</h1>
          <p class="mt-2 text-sm text-gray-700">
            Регистър на получени данъчни документи според ЗДДС
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate={~p"/vat/purchase-register/new"}
            class="block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
          >
            Нов запис
          </.link>
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
                      Доставчик
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Данъчна основа
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      ДДС
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      За приспадане
                    </th>
                    <th class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Действия</span>
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
                        <%= entry.supplier_name %>
                        <%= if entry.supplier_vat_number do %>
                          <br />
                          <span class="text-xs">ДДС: <%= entry.supplier_vat_number %></span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.taxable_base) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.vat_amount) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-right font-mono">
                        <span class={if entry.is_deductible, do: "text-green-700", else: "text-red-700"}>
                          <%= format_amount(entry.deductible_vat_amount) %>
                        </span>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <.link
                          navigate={~p"/vat/purchase-register/#{entry.id}/edit"}
                          class="text-indigo-600 hover:text-indigo-900 mr-4"
                        >
                          Редактирай
                        </.link>

                        <button
                          type="button"
                          phx-click="delete_entry"
                          phx-value-id={entry.id}
                          data-confirm="Сигурни ли сте, че искате да изтриете този запис?"
                          class="text-red-600 hover:text-red-900"
                        >
                          Изтрий
                        </button>
                      </td>
                    </tr>
                  <% end %>

                  <%= if Enum.empty?(@entries) do %>
                    <tr>
                      <td colspan="8" class="py-8 text-center text-sm text-gray-500">
                        Няма записи за избрания период
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <%= if @show_form do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-screen items-center justify-center px-4">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

            <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl sm:p-6">
              <.live_component
                module={CyberWeb.VatPurchaseRegisterLive.FormComponent}
                id={@entry.id || :new}
                entry={@entry}
                tenant_id={@tenant_id}
                period_year={@period_year}
                period_month={@period_month}
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
