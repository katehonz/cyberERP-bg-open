defmodule CyberWeb.SaleLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Sales
  alias Decimal, as: D

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Продажби")
     |> assign(:sales, [])
     |> assign(:selected_sale, nil)
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)
     |> load_sales()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:selected_sale, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    sale = Sales.get_sale!(@tenant_id, id)
    assign(socket, :selected_sale, sale)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_sales()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_sales()}
  end

  def handle_event("filter_dates", %{"from" => from, "to" => to}, socket) do
    {:noreply,
     socket
     |> assign(:date_from, from)
     |> assign(:date_to, to)
     |> load_sales()}
  end

  def handle_event("show", %{"id" => id}, socket) do
    sale = Sales.get_sale!(@tenant_id, id)

    {:noreply,
     socket
     |> assign(:selected_sale, sale)
     |> push_patch(to: ~p"/sales/#{sale.id}")}
  end

  def handle_event("close_panel", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_sale, nil)
     |> push_patch(to: ~p"/sales")}
  end

  defp load_sales(socket) do
    opts = build_filter_opts(socket)
    sales = Sales.list_sales(@tenant_id, opts)
    assign(socket, :sales, sales)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:status, socket.assigns.filter_status)
    |> maybe_put(:search, socket.assigns.search_query)
    |> maybe_put(:from, socket.assigns.date_from)
    |> maybe_put(:to, socket.assigns.date_to)
  end

  defp maybe_put(opts, _key, value) when value in [nil, "", "all"], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp format_money(%Decimal{} = amount) do
    amount
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_float(amount) do
    amount
    |> D.from_float()
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_integer(amount) do
    amount
    |> D.new()
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_binary(amount), do: amount
  defp format_money(_), do: "0.00"

  defp format_decimal_string(value) do
    case String.split(value, ".") do
      [whole, decimals] ->
        padded = decimals |> String.pad_trailing(2, "0") |> String.slice(0, 2)
        whole <> "." <> padded

      [whole] ->
        whole <> ".00"
    end
  end

  defp status_badge("pending"),
    do: "inline-flex rounded-full bg-amber-100 px-2 py-1 text-xs font-medium text-amber-600"

  defp status_badge("paid"),
    do: "inline-flex rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-600"

  defp status_badge("void"),
    do: "inline-flex rounded-full bg-gray-200 px-2 py-1 text-xs font-medium text-gray-700"

  defp status_badge("overdue"),
    do: "inline-flex rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-600"

  defp status_badge(_),
    do: "inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600"

  defp humanize_status("pending"), do: "Очаква плащане"
  defp humanize_status("paid"), do: "Платена"
  defp humanize_status("void"), do: "Анулирана"
  defp humanize_status("overdue"), do: "Просрочена"
  defp humanize_status(status), do: String.capitalize(status)

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> Calendar.strftime("%d.%m.%Y %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = naive) do
    naive |> Calendar.strftime("%d.%m.%Y %H:%M")
  end

  defp format_datetime(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Продажби</h1>
          <p class="mt-1 text-sm text-gray-600">Обобщение на продажби, регистрирани през POS и фактури</p>
        </div>
        <.link patch={~p"/pos"} class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700">
          POS точка
        </.link>
      </div>

      <div class="grid gap-4 border border-gray-200 bg-white p-4 shadow-sm sm:grid-cols-4 sm:items-end">
        <div>
          <label class="text-xs font-medium text-gray-500">Статус</label>
          <select name="status" phx-change="filter_status" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_status == "all"}>Всички</option>
            <%= for status <- ["pending", "paid", "void", "overdue"] do %>
              <option value={status} selected={@filter_status == status}><%= humanize_status(status) %></option>
            <% end %>
          </select>
        </div>
        <div class="sm:col-span-2">
          <label class="text-xs font-medium text-gray-500">Търсене</label>
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Номер или клиент"
            phx-change="search"
            phx-debounce="300"
            class="mt-1 w-full rounded-md border-gray-300 text-sm"
          />
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-xs font-medium text-gray-500">От дата</label>
            <input type="date" name="from" value={@date_from} phx-change="filter_dates" class="mt-1 w-full rounded-md border-gray-300 text-sm" />
          </div>
          <div>
            <label class="text-xs font-medium text-gray-500">До дата</label>
            <input type="date" name="to" value={@date_to} phx-change="filter_dates" class="mt-1 w-full rounded-md border-gray-300 text-sm" />
          </div>
        </div>
      </div>

      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Номер</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Клиент</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Дата</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Статус</th>
              <th class="px-4 py-2 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Сума</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for sale <- @sales do %>
              <tr>
                <td class="px-4 py-2 text-sm font-medium text-gray-900"><%= sale.invoice_number %></td>
                <td class="px-4 py-2 text-sm text-gray-600"><%= sale.customer_name %></td>
                <td class="px-4 py-2 text-sm text-gray-500"><%= format_datetime(sale.date) %></td>
                <td class="px-4 py-2 text-sm"><span class={status_badge(sale.status)}><%= humanize_status(sale.status) %></span></td>
                <td class="px-4 py-2 text-right text-sm font-semibold text-gray-900"><%= format_money(sale.amount) %></td>
                <td class="px-4 py-2 text-right text-sm">
                  <button phx-click="show" phx-value-id={sale.id} class="text-indigo-600 hover:text-indigo-700">Детайли</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @selected_sale do %>
        <div class="rounded-lg border border-indigo-100 bg-white p-6 shadow-lg">
          <div class="flex items-start justify-between">
            <div>
              <h2 class="text-lg font-semibold text-gray-900">Продажба <%= @selected_sale.invoice_number %></h2>
              <p class="text-sm text-gray-500">Дата: <%= format_datetime(@selected_sale.date) %></p>
            </div>
            <button phx-click="close_panel" class="text-sm text-gray-500 hover:text-gray-700">Затвори</button>
          </div>

          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <p class="text-xs uppercase text-gray-500">Клиент</p>
              <p class="text-sm text-gray-800"><%= @selected_sale.customer_name %></p>
              <p class="text-sm text-gray-500"><%= @selected_sale.customer_email %></p>
              <p class="text-sm text-gray-500"><%= @selected_sale.customer_phone %></p>
            </div>
            <div>
              <p class="text-xs uppercase text-gray-500">Информация</p>
              <p class="text-sm text-gray-800">Статус: <span class={status_badge(@selected_sale.status)}><%= humanize_status(@selected_sale.status) %></span></p>
              <p class="text-sm text-gray-800">Плащане: <%= @selected_sale.payment_method || "-" %></p>
              <p class="text-sm text-gray-800">Сума: <%= format_money(@selected_sale.amount) %></p>
            </div>
          </div>

          <div class="mt-6 overflow-hidden rounded-lg border border-gray-200">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-3 py-2 text-left">Описание</th>
                  <th class="px-3 py-2 text-right">Кол.</th>
                  <th class="px-3 py-2 text-right">Ед. цена</th>
                  <th class="px-3 py-2 text-right">Общо</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <%= for item <- @selected_sale.sale_items || [] do %>
                  <tr>
                    <td class="px-3 py-2 text-gray-700"><%= item.description %></td>
                    <td class="px-3 py-2 text-right text-gray-600"><%= D.to_string(item.quantity) %></td>
                    <td class="px-3 py-2 text-right text-gray-600"><%= format_money(item.unit_price) %></td>
                    <td class="px-3 py-2 text-right font-medium text-gray-900"><%= format_money(item.total_amount) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
