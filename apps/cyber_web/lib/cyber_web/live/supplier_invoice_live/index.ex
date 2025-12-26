defmodule CyberWeb.SupplierInvoiceLive.Index do
  use CyberWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias CyberCore.Repo
  alias CyberCore.Purchase
  alias CyberCore.Purchase.SupplierInvoiceLine
  alias CyberCore.Inventory
  alias CyberCore.Contacts
  alias Decimal, as: D

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    suppliers = load_suppliers()
    products = Inventory.list_products(@tenant_id)
    purchase_orders = Purchase.list_purchase_orders(@tenant_id)
    default_currency = CyberCore.Settings.get_default_currency(@tenant_id)

    {:ok,
     socket
     |> assign(:page_title, "Фактури от доставчици")
     |> assign(:supplier_invoices, [])
     |> assign(:supplier_invoice, nil)
     |> assign(:form, nil)
     |> assign(:invoice_lines, [new_line_template()])
     |> assign(:invoice_totals, totals_for([]))
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)
     |> assign(:suppliers, suppliers)
     |> assign(:products, products)
     |> assign(:purchase_orders, purchase_orders)
     |> assign(:selected_supplier_id, nil)
     |> assign(:selected_purchase_order_id, nil)
     |> assign(:default_currency, default_currency)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)
     |> load_invoices()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:supplier_invoice, nil)
    |> assign(:form, nil)
    |> assign(:invoice_lines, [new_line_template()])
    |> assign(:invoice_totals, totals_for([]))
    |> assign(:selected_supplier_id, nil)
    |> assign(:selected_purchase_order_id, nil)
  end

  defp apply_action(socket, :new, _params) do
    invoice = %Purchase.SupplierInvoice{
      invoice_date: Date.utc_today(),
      due_date: Date.add(Date.utc_today(), 30),
      tax_event_date: Date.utc_today(),
      status: "draft",
      currency: socket.assigns.default_currency,
      vat_document_type: "01"
    }

    changeset = Purchase.change_supplier_invoice(invoice)

    socket
    |> assign(:page_title, "Нова фактура от доставчик")
    |> assign(:supplier_invoice, invoice)
    |> assign(:form, to_form(changeset))
    |> assign(:invoice_lines, [new_line_template()])
    |> assign(:invoice_totals, totals_for([]))
    |> assign(:selected_supplier_id, nil)
    |> assign(:selected_purchase_order_id, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    invoice = Purchase.get_supplier_invoice!(@tenant_id, id, [:supplier_invoice_lines, :supplier])
    changeset = Purchase.change_supplier_invoice(invoice)

    lines =
      invoice.supplier_invoice_lines
      |> Enum.sort_by(& &1.line_no)
      |> Enum.map(&line_from_struct/1)

    totals = totals_for(lines)

    socket
    |> assign(:page_title, "Редакция на фактура")
    |> assign(:supplier_invoice, invoice)
    |> assign(:form, to_form(changeset))
    |> assign(:invoice_lines, lines)
    |> assign(:invoice_totals, totals)
    |> assign(:selected_supplier_id, invoice.supplier_id)
    |> assign(:selected_purchase_order_id, invoice.purchase_order_id)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_invoices()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_invoices()}
  end

  def handle_event("filter_dates", %{"from" => from, "to" => to}, socket) do
    {:noreply,
     socket
     |> assign(:date_from, from)
     |> assign(:date_to, to)
     |> load_invoices()}
  end

  def handle_event(
        "select_supplier",
        %{"supplier_invoice" => %{"supplier_id" => supplier_id}} = _params,
        socket
      ) do
    supplier_id = parse_integer(supplier_id)
    supplier = Enum.find(socket.assigns.suppliers, &(&1.id == supplier_id))

    updated_params =
      socket.assigns.form
      |> form_params()
      |> Map.merge(%{
        "supplier_id" => supplier_id,
        "supplier_name" => (supplier && supplier.name) || "",
        "supplier_address" => (supplier && supplier.address) || "",
        "supplier_vat_number" => (supplier && supplier.vat_number) || ""
      })

    invoice = socket.assigns.supplier_invoice || %Purchase.SupplierInvoice{}
    changeset = Purchase.change_supplier_invoice(invoice, updated_params)

    {:noreply,
     socket
     |> assign(:selected_supplier_id, supplier_id)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("select_purchase_order", %{"purchase_order_id" => po_id}, socket) do
    {:noreply, assign(socket, :selected_purchase_order_id, parse_integer(po_id))}
  end

  def handle_event("add_line", _params, socket) do
    lines = socket.assigns.invoice_lines ++ [new_line_template()]
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("remove_line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    lines = List.delete_at(socket.assigns.invoice_lines, index)
    lines = if lines == [], do: [new_line_template()], else: lines
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("update_lines", %{"lines" => lines_params}, socket) do
    lines = sanitize_line_params(lines_params)
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event(
        "validate",
        %{"supplier_invoice" => invoice_params, "lines" => lines_params},
        socket
      ) do
    lines = sanitize_line_params(lines_params)
    invoice = socket.assigns.supplier_invoice || %Purchase.SupplierInvoice{}

    changeset =
      invoice
      |> Purchase.change_supplier_invoice(
        normalize_invoice_params(
          invoice_params,
          socket.assigns.selected_supplier_id,
          socket.assigns.selected_purchase_order_id,
          socket.assigns.suppliers,
          socket.assigns.default_currency
        )
      )
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign_with_totals(lines)}
  end

  def handle_event(
        "save",
        %{"supplier_invoice" => invoice_params, "lines" => lines_params},
        socket
      ) do
    lines = sanitize_line_params(lines_params)

    attrs =
      normalize_invoice_params(
        invoice_params,
        socket.assigns.selected_supplier_id,
        socket.assigns.selected_purchase_order_id,
        socket.assigns.suppliers,
        socket.assigns.default_currency
      )

    line_attrs = Enum.with_index(lines, 1) |> Enum.map(&line_to_attrs/1)

    save_supplier_invoice(socket, socket.assigns.live_action, attrs, line_attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    invoice = Purchase.get_supplier_invoice!(@tenant_id, id)
    {:ok, _} = Purchase.delete_supplier_invoice(invoice)

    {:noreply,
     socket
     |> put_flash(:info, "Фактурата беше изтрита")
     |> load_invoices()}
  end

  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

  @impl true
  def handle_info({:search_modal_selected, %{item: product, field: :product_id}}, socket) do
    index = socket.assigns.product_search_line_index

    lines =
      List.update_at(socket.assigns.invoice_lines, index, fn line ->
        line
        |> Map.put(:product_id, product.id)
        |> Map.put(:description, product.description || "")
        |> Map.put(:unit_price, to_string(product.price || 0))
        |> Map.put(:tax_rate, to_string(product.tax_rate || 20))
      end)

    {:noreply,
     socket
     |> assign(:invoice_lines, lines)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  @impl true
  def handle_info({:search_modal_cancelled, %{field: :product_id}}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  defp save_supplier_invoice(socket, :new, attrs, line_attrs) do
    case Purchase.create_supplier_invoice_with_lines(attrs, line_attrs) do
      {:ok, _invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Фактурата беше създадена")
         |> assign(:supplier_invoice, nil)
         |> assign(:form, nil)
         |> assign(:invoice_lines, [new_line_template()])
         |> assign(:invoice_totals, totals_for([]))
         |> load_invoices()
         |> push_patch(to: ~p"/supplier-invoices")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_supplier_invoice(socket, :edit, attrs, line_attrs) do
    invoice = Purchase.get_supplier_invoice!(@tenant_id, socket.assigns.supplier_invoice.id)

    case Purchase.update_supplier_invoice(invoice, attrs) do
      {:ok, updated_invoice} ->
        case replace_invoice_lines(updated_invoice, line_attrs) do
          {:ok, _lines} ->
            {:noreply,
             socket
             |> put_flash(:info, "Фактурата беше обновена")
             |> load_invoices()
             |> push_patch(to: ~p"/supplier-invoices")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp replace_invoice_lines(invoice, line_attrs) do
    Repo.transaction(fn ->
      from(l in SupplierInvoiceLine, where: l.supplier_invoice_id == ^invoice.id)
      |> Repo.delete_all()

      case insert_lines(invoice, line_attrs) do
        {:ok, lines} -> lines
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_lines(invoice, line_attrs) do
    line_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.merge(attrs, %{tenant_id: invoice.tenant_id, supplier_invoice_id: invoice.id})

      %SupplierInvoiceLine{}
      |> SupplierInvoiceLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp handle_batch_result(results) do
    case Enum.split_with(results, fn
           {:ok, _} -> true
           _ -> false
         end) do
      {oks, []} -> {:ok, Enum.map(oks, fn {:ok, record} -> record end)}
      {_, [{:error, changeset} | _]} -> {:error, changeset}
    end
  end

  defp assign_with_totals(socket, lines) do
    socket
    |> assign(:invoice_lines, lines)
    |> assign(:invoice_totals, totals_for(lines))
  end

  defp load_invoices(socket) do
    opts = build_filter_opts(socket)
    invoices = Purchase.list_supplier_invoices(@tenant_id, opts)
    assign(socket, :supplier_invoices, invoices)
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

  defp sanitize_line_params(lines_params) do
    lines_params
    |> Enum.map(fn {index, params} ->
      %{
        index: String.to_integer(index),
        product_id: parse_integer(params["product_id"]),
        description: params["description"] || "",
        unit: params["unit"] || "бр.",
        quantity: params["quantity"] || "1",
        unit_price: params["unit_price"] || "0",
        discount_percent: params["discount_percent"] || "0",
        tax_rate: params["tax_rate"] || "20"
      }
    end)
    |> Enum.sort_by(& &1.index)
  end

  defp line_to_attrs({line, index}) do
    %{
      line_no: index,
      product_id: line.product_id,
      description: line.description,
      unit_of_measure: line.unit,
      quantity: to_decimal(line.quantity),
      unit_price: to_decimal(line.unit_price),
      discount_percent: to_decimal(line.discount_percent),
      tax_rate: to_decimal(line.tax_rate)
    }
  end

  defp line_from_struct(line) do
    %{
      index: line.line_no || 1,
      product_id: line.product_id,
      description: line.description,
      unit: line.unit_of_measure,
      quantity: D.to_string(line.quantity || D.new(1)),
      unit_price: D.to_string(line.unit_price || D.new(0)),
      discount_percent: D.to_string(line.discount_percent || D.new(0)),
      tax_rate: D.to_string(line.tax_rate || D.new("20"))
    }
  end

  defp totals_for(lines) do
    Enum.reduce(lines, %{subtotal: D.new(0), tax: D.new(0), total: D.new(0)}, fn line, acc ->
      quantity = to_decimal(line.quantity)
      unit_price = to_decimal(line.unit_price)
      discount = to_decimal(line.discount_percent)
      tax_rate = to_decimal(line.tax_rate)

      gross = D.mult(quantity, unit_price)
      discount_amount = gross |> D.mult(discount) |> D.div(D.new(100))
      subtotal = D.sub(gross, discount_amount)
      tax = subtotal |> D.mult(tax_rate) |> D.div(D.new(100))
      total = D.add(subtotal, tax)

      %{
        subtotal: D.add(acc.subtotal, subtotal),
        tax: D.add(acc.tax, tax),
        total: D.add(acc.total, total)
      }
    end)
  end

  defp new_line_template do
    %{
      index: System.unique_integer([:positive]),
      product_id: nil,
      description: "",
      unit: "бр.",
      quantity: "1",
      unit_price: "0.00",
      discount_percent: "0",
      tax_rate: "20"
    }
  end

  defp normalize_invoice_params(
         params,
         selected_supplier_id,
         selected_po_id,
         suppliers,
         default_currency
       ) do
    params
    |> Map.put("tenant_id", @tenant_id)
    |> Map.put_new("currency", default_currency)
    |> maybe_put_supplier(selected_supplier_id, suppliers)
    |> maybe_put_purchase_order(selected_po_id)
  end

  defp maybe_put_supplier(params, nil, _suppliers), do: params

  defp maybe_put_supplier(params, supplier_id, suppliers) do
    case Enum.find(suppliers, &(&1.id == supplier_id)) do
      nil ->
        params

      supplier ->
        params
        |> Map.put("supplier_id", supplier.id)
        |> Map.put_new("supplier_name", supplier.name)
        |> Map.put_new("supplier_address", supplier.address)
        |> Map.put_new("supplier_vat_number", supplier.vat_number)
    end
  end

  defp maybe_put_purchase_order(params, nil), do: params
  defp maybe_put_purchase_order(params, po_id), do: Map.put(params, "purchase_order_id", po_id)

  defp load_suppliers do
    Contacts.list_contacts(@tenant_id, is_supplier: true)
    |> Enum.map(fn supplier ->
      %{
        id: supplier.id,
        name: supplier.name,
        address: supplier.address,
        vat_number: supplier.vat_number
      }
    end)
  end

  defp to_decimal(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        D.new(0)

      v ->
        case D.parse(v) do
          {:ok, decimal} -> decimal
          :error -> D.new(0)
        end
    end
  end

  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: D.new(value)
  defp to_decimal(value) when is_float(value), do: D.from_float(value)
  defp to_decimal(nil), do: D.new(0)

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp form_params(nil), do: %{}
  defp form_params(form), do: form.params || %{}

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

  defp status_badge("draft"),
    do: "inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600"

  defp status_badge("received"),
    do: "inline-flex rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-600"

  defp status_badge("approved"),
    do: "inline-flex rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-600"

  defp status_badge("paid"),
    do: "inline-flex rounded-full bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-600"

  defp status_badge("partially_paid"),
    do: "inline-flex rounded-full bg-amber-100 px-2 py-1 text-xs font-medium text-amber-600"

  defp status_badge("overdue"),
    do: "inline-flex rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-600"

  defp status_badge("cancelled"),
    do: "inline-flex rounded-full bg-gray-200 px-2 py-1 text-xs font-medium text-gray-700"

  defp status_badge(_),
    do: "inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600"

  defp humanize_status("draft"), do: "Чернова"
  defp humanize_status("received"), do: "Получена"
  defp humanize_status("approved"), do: "Одобрена"
  defp humanize_status("paid"), do: "Платена"
  defp humanize_status("partially_paid"), do: "Частично платена"
  defp humanize_status("overdue"), do: "Просрочена"
  defp humanize_status("cancelled"), do: "Отказана"
  defp humanize_status(status), do: String.capitalize(status)

  defp status_options do
    [
      {"Чернова", "draft"},
      {"Получена", "received"},
      {"Одобрена", "approved"},
      {"Платена", "paid"},
      {"Частично платена", "partially_paid"},
      {"Просрочена", "overdue"},
      {"Отказана", "cancelled"}
    ]
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp get_product_name(nil), do: ""
  defp get_product_name(product_id) do
    try do
      product = CyberCore.Inventory.get_product!(@tenant_id, product_id)
      product.name
    rescue
      Ecto.NoResultsError -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Фактури от доставчици</h1>
          <p class="mt-1 text-sm text-gray-600">Проследяване на входящи фактури и задължения към доставчици</p>
        </div>
        <.link
          patch={~p"/supplier-invoices/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нова фактура
        </.link>
      </div>

      <div class="grid gap-4 border border-gray-200 bg-white p-4 shadow-sm sm:grid-cols-4 sm:items-end">
        <div>
          <label class="text-xs font-medium text-gray-500">Статус</label>
          <select name="status" phx-change="filter_status" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_status == "all"}>Всички</option>
            <%= for {_label, status} <- status_options() do %>
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
            placeholder="Номер на фактура или доставчик"
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
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Доставчик</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Дата</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Статус</th>
              <th class="px-4 py-2 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Обща сума</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for invoice <- @supplier_invoices do %>
              <tr>
                <td class="px-4 py-2 text-sm font-medium text-gray-900"><%= invoice.invoice_no %></td>
                <td class="px-4 py-2 text-sm text-gray-600"><%= invoice.supplier_name %></td>
                <td class="px-4 py-2 text-sm text-gray-500"><%= format_date(invoice.invoice_date) %></td>
                <td class="px-4 py-2 text-sm"><span class={status_badge(invoice.status)}><%= humanize_status(invoice.status) %></span></td>
                <td class="px-4 py-2 text-right text-sm font-semibold text-gray-900"><%= format_money(invoice.total_amount) %></td>
                <td class="px-4 py-2 text-right text-sm">
                  <div class="flex justify-end gap-2">
                    <.link patch={~p"/supplier-invoices/#{invoice.id}/edit"} class="text-indigo-600 hover:text-indigo-700">Редакция</.link>
                    <button phx-click="delete" phx-value-id={invoice.id} data-confirm="Сигурни ли сте?" class="text-red-500 hover:text-red-600">
                      Изтрий
                    </button>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="rounded-lg border border-indigo-100 bg-white p-6 shadow-lg">
          <h2 class="text-lg font-semibold text-gray-900">
            <%= if @live_action == :new, do: "Нова фактура", else: "Редакция" %>
          </h2>

          <.simple_form
            for={@form}
            id="supplier-invoice-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:invoice_no]} label="Номер" />
              <.input field={@form[:supplier_invoice_no]} label="Номер на доставчика" />
              <.input field={@form[:invoice_date]} type="date" label="Дата" />
              <.input field={@form[:tax_event_date]} type="date" label="Дата на данъчното събитие (ДДС дата)" />
              <.input field={@form[:due_date]} type="date" label="Падеж" />
              <.input field={@form[:status]} type="select" label="Статус" options={status_options()} />
              <div>
                <label class="text-xs font-medium text-gray-500">Поръчка</label>
                <select name="supplier_invoice[purchase_order_id]" phx-change="select_purchase_order" class="mt-1 w-full rounded-md border-gray-300 text-sm">
                  <option value="">(без)</option>
                  <%= for order <- @purchase_orders do %>
                    <option value={order.id} selected={@selected_purchase_order_id == order.id}><%= order.order_no %></option>
                  <% end %>
                </select>
              </div>
            </div>

            <div class="space-y-2 border-t border-gray-200 pt-4">
              <h3 class="text-sm font-semibold text-gray-800">ДДС данни (ЗДДС)</h3>
              <div class="grid gap-4 sm:grid-cols-2">
                <div>
                  <label for="vat_document_type" class="block text-xs font-medium text-gray-500">
                    Вид документ <span class="text-red-500">*</span>
                  </label>
                  <select
                    name="supplier_invoice[vat_document_type]"
                    id="vat_document_type"
                    required
                    class="mt-1 w-full rounded-md border-gray-300 text-sm focus:border-indigo-500 focus:ring-indigo-500"
                  >
                    <option value="">Изберете вид документ...</option>
                    <%= for {code, name} <- CyberCore.Purchase.SupplierInvoice.vat_document_types() do %>
                      <option
                        value={code}
                        selected={Phoenix.HTML.Form.input_value(@form, :vat_document_type) == code}
                      >
                        <%= code %> - <%= name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label for="vat_purchase_operation" class="block text-xs font-medium text-gray-500">
                    Операция при покупка
                  </label>
                  <select
                    name="supplier_invoice[vat_purchase_operation]"
                    id="vat_purchase_operation"
                    class="mt-1 w-full rounded-md border-gray-300 text-sm focus:border-indigo-500 focus:ring-indigo-500"
                  >
                    <option value="">Не е приложимо</option>
                    <%= for {code, name} <- CyberCore.Purchase.SupplierInvoice.vat_purchase_operations() do %>
                      <option
                        value={code}
                        selected={Phoenix.HTML.Form.input_value(@form, :vat_purchase_operation) == code}
                      >
                        <%= code %> - <%= name %>
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="text-xs font-medium text-gray-500">Доставчик</label>
                <select name="supplier_invoice[supplier_id]" phx-change="select_supplier" class="mt-1 w-full rounded-md border-gray-300 text-sm">
                  <option value="">Изберете доставчик</option>
                  <%= for supplier <- @suppliers do %>
                    <option value={supplier.id} selected={@selected_supplier_id == supplier.id}><%= supplier.name %></option>
                  <% end %>
                </select>
              </div>
              <.input field={@form[:supplier_name]} label="Име" />
              <.input field={@form[:supplier_vat_number]} label="ДДС номер" />
              <.input field={@form[:supplier_address]} label="Адрес" />
            </div>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-gray-800">Редове</h3>
                <button type="button" phx-click="add_line" class="inline-flex items-center gap-1 rounded-md bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600 hover:bg-indigo-100">
                  + Добави ред
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left">Продукт</th>
                      <th class="px-3 py-2 text-left">Описание</th>
                      <th class="px-3 py-2 text-right">Кол.</th>
                      <th class="px-3 py-2 text-right">Ед. цена</th>
                      <th class="px-3 py-2 text-right">Отстъпка %</th>
                      <th class="px-3 py-2 text-right">ДДС %</th>
                      <th class="px-3 py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <%= for {line, index} <- Enum.with_index(@invoice_lines) do %>
                      <tr>
                        <td class="px-3 py-2">
                          <div class="flex rounded-md shadow-sm">
                            <input
                              type="text"
                              class="w-full rounded-none rounded-l-md border-gray-300 bg-gray-100"
                              value={get_product_name(line.product_id)}
                              readonly="readonly"
                            />
                            <button
                              type="button"
                              class="relative -ml-px inline-flex items-center space-x-2 rounded-r-md border border-gray-300 bg-gray-50 px-2 py-1 text-sm font-medium text-gray-700 hover:bg-gray-100"
                              phx-click="open_product_search"
                              phx-value-index={index}
                            >
                              <Heroicons.magnifying_glass class="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                        <td class="px-3 py-2">
                          <input type="text" name={"lines[#{index}][description]"} value={line.description} class="w-full rounded-md border-gray-300 text-sm" phx-debounce="300" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][quantity]"} value={line.quantity} class="w-24 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][unit_price]"} value={line.unit_price} class="w-28 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][discount_percent]"} value={line.discount_percent} class="w-24 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][tax_rate]"} value={line.tax_rate} class="w-24 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2 text-right">
                          <button type="button" phx-click="remove_line" phx-value-index={index} class="text-xs text-red-500 hover:text-red-600">Премахни</button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex justify-end gap-8 text-sm">
                <div>
                  <div class="text-gray-500">Междинна сума</div>
                  <div class="text-right font-medium text-gray-900"><%= format_money(@invoice_totals.subtotal) %></div>
                </div>
                <div>
                  <div class="text-gray-500">ДДС</div>
                  <div class="text-right font-medium text-gray-900"><%= format_money(@invoice_totals.tax) %></div>
                </div>
                <div>
                  <div class="text-gray-500">Общо</div>
                  <div class="text-right text-lg font-semibold text-gray-900"><%= format_money(@invoice_totals.total) %></div>
                </div>
              </div>
            </div>

            <.input field={@form[:notes]} type="textarea" label="Бележки" rows={3} />

            <:actions>
              <.button type="submit">Запази</.button>
              <.link patch={~p"/supplier-invoices"} class="text-sm text-gray-500 hover:text-gray-700">Отказ</.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="product-search-modal"
      show={@show_product_search_modal}
      title="Търсене на продукт"
      search_fun={&CyberCore.Inventory.search_products(1, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:sku, "text-sm text-gray-600", fn v -> "SKU: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:product_id}
    />
    """
  end
end
