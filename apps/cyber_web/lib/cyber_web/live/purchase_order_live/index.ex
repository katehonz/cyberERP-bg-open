defmodule CyberWeb.PurchaseOrderLive.Index do
  use CyberWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias CyberCore.Repo
  alias CyberCore.Purchase
  alias CyberCore.Purchase.PurchaseOrderLine
  alias CyberCore.Inventory
  alias CyberCore.Contacts
  alias Decimal, as: D

  @tenant_id 1
  @default_currency "BGN"

  @impl true
  def mount(_params, _session, socket) do
    products = load_products()

    {:ok,
     socket
     |> assign(:page_title, "Поръчки за покупки")
     |> assign(:purchase_orders, [])
     |> assign(:purchase_order, nil)
     |> assign(:form, nil)
     |> assign(:order_lines, [new_line_template()])
     |> assign(:order_totals, totals_for([]))
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)
     |> assign(:products, products)
     |> assign(:selected_supplier_id, nil)
     |> assign(:show_supplier_search_modal, false)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)
     |> load_purchase_orders()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Поръчки за покупки")
    |> assign(:purchase_order, nil)
    |> assign(:form, nil)
    |> assign(:order_lines, [new_line_template()])
    |> assign(:order_totals, totals_for([]))
    |> assign(:selected_supplier_id, nil)
  end

  defp apply_action(socket, :new, _params) do
    order = %Purchase.PurchaseOrder{
      order_date: Date.utc_today(),
      expected_date: Date.add(Date.utc_today(), 7),
      currency: @default_currency,
      status: "draft"
    }

    changeset = Purchase.change_purchase_order(order)

    socket
    |> assign(:page_title, "Нова покупка")
    |> assign(:purchase_order, order)
    |> assign(:form, to_form(changeset))
    |> assign(:order_lines, [new_line_template()])
    |> assign(:order_totals, totals_for([]))
    |> assign(:selected_supplier_id, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    order = Purchase.get_purchase_order!(@tenant_id, id, [:purchase_order_lines])
    changeset = Purchase.change_purchase_order(order)

    lines =
      order.purchase_order_lines
      |> Enum.sort_by(& &1.line_no)
      |> Enum.map(&line_from_struct/1)

    totals = totals_for(lines)

    socket
    |> assign(:page_title, "Редакция на покупка")
    |> assign(:purchase_order, order)
    |> assign(:form, to_form(changeset))
    |> assign(:order_lines, lines)
    |> assign(:order_totals, totals)
    |> assign(:selected_supplier_id, order.supplier_id)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_purchase_orders()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_purchase_orders()}
  end

  def handle_event("filter_dates", %{"from" => from, "to" => to}, socket) do
    {:noreply,
     socket
     |> assign(:date_from, from)
     |> assign(:date_to, to)
     |> load_purchase_orders()}
  end

  def handle_event("open_supplier_search", _, socket) do
    {:noreply, assign(socket, :show_supplier_search_modal, true)}
  end



  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

  def handle_event("add_line", _params, socket) do
    lines = socket.assigns.order_lines ++ [new_line_template()]
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("remove_line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    lines = List.delete_at(socket.assigns.order_lines, index)
    lines = if lines == [], do: [new_line_template()], else: lines
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("update_lines", %{"lines" => lines_params}, socket) do
    old_lines = socket.assigns.order_lines
    products = socket.assigns.products

    new_lines =
      lines_params
      |> Enum.to_list()
      |> Enum.sort_by(fn {i, _} -> String.to_integer(i) end)
      |> Enum.with_index()
      |> Enum.map(fn {{_index_str, params}, index} ->
        old_line = Enum.at(old_lines, index)
        product_id = parse_integer(params["product_id"])

        line = %{
          index: old_line.index,
          product_id: product_id,
          description: params["description"] || "",
          unit: params["unit"] || "бр.",
          quantity: params["quantity"] || "1",
          unit_price: params["unit_price"] || "0",
          tax_rate: params["tax_rate"] || "20",
          discount_percent: params["discount_percent"] || "0"
        }

        # If product_id changed, update the line from product data
        if product_id != old_line.product_id do
          case Enum.find(products, &(&1.id == product_id)) do
            nil ->
              line

            product ->
              line
              |> Map.put(:description, product.description || "")
              |> Map.put(:unit_price, D.to_string(product.cost || D.new(0)))
              |> Map.put(:unit, product.unit || "бр.")
          end
        else
          line
        end
      end)

    {:noreply, assign_with_totals(socket, new_lines)}
  end

  def handle_event(
        "validate",
        %{"purchase_order" => order_params, "lines" => lines_params},
        socket
      ) do
    lines = sanitize_line_params(lines_params)
    order = socket.assigns.purchase_order || %Purchase.PurchaseOrder{}

    changeset =
      order
      |> Purchase.change_purchase_order(
        normalize_order_params(
          order_params,
          socket.assigns.selected_supplier_id,
          socket.assigns.suppliers
        )
      )
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign_with_totals(lines)}
  end

  def handle_event("save", %{"purchase_order" => order_params, "lines" => lines_params}, socket) do
    lines = sanitize_line_params(lines_params)

    attrs =
      normalize_order_params(
        order_params,
        socket.assigns.selected_supplier_id,
        socket.assigns.suppliers
      )

    line_attrs = Enum.with_index(lines, 1) |> Enum.map(&line_to_attrs/1)

    save_purchase_order(socket, socket.assigns.live_action, attrs, line_attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    order = Purchase.get_purchase_order!(@tenant_id, id)
    {:ok, _} = Purchase.delete_purchase_order(order)

    {:noreply,
     socket
     |> put_flash(:info, "Поръчката беше изтрита")
     |> load_purchase_orders()}
  end

  @impl true
  def handle_info({:search_modal_selected, %{item: supplier, field: :supplier_id}}, socket) do
    supplier_id = supplier.id

    updated_params =
      socket.assigns.form
      |> form_params()
      |> Map.merge(%{
        "supplier_id" => supplier_id,
        "supplier_name" => supplier.name,
        "supplier_address" => supplier.address,
        "supplier_vat_number" => supplier.vat_number
      })

    order = socket.assigns.purchase_order || %Purchase.PurchaseOrder{}
    changeset = Purchase.change_purchase_order(order, updated_params)

    {:noreply,
     socket
     |> assign(:selected_supplier_id, supplier_id)
     |> assign(:form, to_form(changeset))
     |> assign(:show_supplier_search_modal, false)}
  end

  def handle_info({:search_modal_cancelled, %{field: :supplier_id}}, socket) do
    {:noreply, assign(socket, :show_supplier_search_modal, false)}
  end

  @impl true
  def handle_info({:search_modal_selected, %{item: product, field: :product_id}}, socket) do
    index = socket.assigns.product_search_line_index

    lines =
      List.update_at(socket.assigns.order_lines, index, fn line ->
        line
        |> Map.put(:product_id, product.id)
        |> Map.put(:description, product.description || "")
        |> Map.put(:unit_price, D.to_string(product.cost || D.new(0)))
        |> Map.put(:unit, product.unit || "бр.")
      end)

    {:noreply,
     socket
     |> assign_with_totals(lines)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end

  def handle_info({:search_modal_cancelled, %{field: :product_id}}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end



  @impl true
  def handle_info({:search_modal_selected, %{item: product, field: :product_id}}, socket) do
    index = socket.assigns.product_search_line_index

    lines =
      List.update_at(socket.assigns.order_lines, index, fn line ->
        line
        |> Map.put(:product_id, product.id)
        |> Map.put(:description, product.description || "")
        |> Map.put(:unit_price, D.to_string(product.cost || D.new(0)))
        |> Map.put(:unit, product.unit || "бр.")
      end)

    {:noreply,
     socket
     |> assign_with_totals(lines)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)}
  end



  defp save_purchase_order(socket, :new, attrs, line_attrs) do
    case Purchase.create_purchase_order_with_lines(attrs, line_attrs) do
      {:ok, _order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Поръчката беше създадена")
         |> assign(:purchase_order, nil)
         |> assign(:form, nil)
         |> assign(:order_lines, [new_line_template()])
         |> assign(:order_totals, totals_for([]))
         |> load_purchase_orders()
         |> push_patch(to: ~p"/purchase-orders")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_purchase_order(socket, :edit, attrs, line_attrs) do
    order = Purchase.get_purchase_order!(@tenant_id, socket.assigns.purchase_order.id)

    case Purchase.update_purchase_order(order, attrs) do
      {:ok, updated_order} ->
        case replace_purchase_lines(updated_order, line_attrs) do
          {:ok, _lines} ->
            {:noreply,
             socket
             |> put_flash(:info, "Поръчката беше обновена")
             |> load_purchase_orders()
             |> push_patch(to: ~p"/purchase-orders")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp replace_purchase_lines(order, line_attrs) do
    Repo.transaction(fn ->
      from(pl in PurchaseOrderLine, where: pl.purchase_order_id == ^order.id)
      |> Repo.delete_all()

      case insert_lines(order, line_attrs) do
        {:ok, lines} -> lines
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_lines(order, line_attrs) do
    line_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.merge(attrs, %{tenant_id: order.tenant_id, purchase_order_id: order.id})

      %PurchaseOrderLine{}
      |> PurchaseOrderLine.changeset(attrs)
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
    |> assign(:order_lines, lines)
    |> assign(:order_totals, totals_for(lines))
  end

  defp load_purchase_orders(socket) do
    opts = build_filter_opts(socket)
    orders = Purchase.list_purchase_orders(@tenant_id, opts)
    assign(socket, :purchase_orders, orders)
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
        tax_rate: params["tax_rate"] || "20",
        discount_percent: params["discount_percent"] || "0"
      }
    end)
  end

  defp line_to_attrs({line, index}) do
    quantity = to_decimal(line.quantity)
    unit_price = to_decimal(line.unit_price)
    discount = to_decimal(line.discount_percent)
    tax_rate = to_decimal(line.tax_rate)

    %{
      line_no: index,
      product_id: line.product_id,
      description: line.description,
      unit_of_measure: line.unit,
      quantity_ordered: quantity,
      unit_price: unit_price,
      discount_percent: discount,
      tax_rate: tax_rate
    }
  end

  defp line_from_struct(line) do
    %{
      index: line.line_no || 1,
      product_id: line.product_id,
      description: line.description,
      unit: line.unit_of_measure,
      quantity: D.to_string(line.quantity_ordered || D.new(1)),
      unit_price: D.to_string(line.unit_price || D.new(0)),
      tax_rate: D.to_string(line.tax_rate || D.new("20")),
      discount_percent: D.to_string(line.discount_percent || D.new(0))
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
      tax_rate: "20",
      discount_percent: "0"
    }
  end

  defp normalize_order_params(params, selected_supplier_id, suppliers) do
    params
    |> Map.put("tenant_id", @tenant_id)
    |> Map.put_new("currency", @default_currency)
    |> maybe_put_supplier(selected_supplier_id, suppliers)
  end

  defp maybe_put_supplier(params, nil, _suppliers), do: params

  defp maybe_put_supplier(params, supplier_id, _suppliers) do
    case CyberCore.Contacts.get_contact!(@tenant_id, supplier_id) do
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

  defp load_products do
    Inventory.list_products(@tenant_id)
  end

  defp form_params(nil), do: %{}
  defp form_params(form), do: form.params || %{}

  defp to_decimal(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        D.new(0)

      v ->
        case D.parse(v) do
          {:ok, decimal} ->
            decimal

          {decimal, ""} ->
            decimal

          :error ->
            D.new(0)
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Поръчки за покупки</h1>
          <p class="mt-1 text-sm text-gray-600">Управление на заявки към доставчици и проследяване на статус</p>
        </div>
        <.link
          patch={~p"/purchase-orders/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нова поръчка
        </.link>
      </div>

      <div class="grid gap-4 border border-gray-200 bg-white p-4 shadow-sm sm:grid-cols-4 sm:items-end">
        <div>
          <label class="text-xs font-medium text-gray-500">Статус</label>
          <select name="status" phx-change="filter_status" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_status == "all"}>Всички</option>
            <%= for status <- ["draft", "sent", "confirmed", "receiving", "received", "cancelled"] do %>
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
            placeholder="Номер на поръчка или доставчик"
            phx-debounce="300"
            phx-change="search"
            class="mt-1 w-full rounded-md border-gray-300 text-sm"
          />
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-xs font-medium text-gray-500">От дата</label>
            <input
              type="date"
              name="from"
              value={@date_from}
              phx-change="filter_dates"
              class="mt-1 w-full rounded-md border-gray-300 text-sm"
            />
          </div>
          <div>
            <label class="text-xs font-medium text-gray-500">До дата</label>
            <input
              type="date"
              name="to"
              value={@date_to}
              phx-change="filter_dates"
              class="mt-1 w-full rounded-md border-gray-300 text-sm"
            />
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
              <th class="px-4 py-2 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Общо</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for order <- @purchase_orders do %>
              <tr>
                <td class="px-4 py-2 text-sm font-medium text-gray-900"><%= order.order_no %></td>
                <td class="px-4 py-2 text-sm text-gray-600"><%= order.supplier_name %></td>
                <td class="px-4 py-2 text-sm text-gray-500"><%= format_date(order.order_date) %></td>
                <td class="px-4 py-2 text-sm">
                  <span class={status_badge(order.status)}><%= humanize_status(order.status) %></span>
                </td>
                <td class="px-4 py-2 text-right text-sm font-medium text-gray-900">
                  <%= format_money(order.total_amount) %>
                </td>
                <td class="px-4 py-2 text-right text-sm">
                  <div class="flex justify-end gap-2">
                    <.link patch={~p"/purchase-orders/#{order.id}/edit"} class="text-indigo-600 hover:text-indigo-700">Редакция</.link>
                    <button phx-click="delete" phx-value-id={order.id} data-confirm="Сигурни ли сте?" class="text-red-500 hover:text-red-600">
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
            <%= if @live_action == :new, do: "Нова поръчка", else: "Редакция" %>
          </h2>

          <.simple_form
            for={@form}
            id="purchase-order-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:order_no]} label="Номер" />
              <.input field={@form[:order_date]} type="date" label="Дата" />
              <.input field={@form[:expected_date]} type="date" label="Очаквана дата" />
              <.input field={@form[:status]} type="select" label="Статус" options={status_options()} />
            </div>

            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="text-xs font-medium text-gray-500">Доставчик</label>
                <div class="mt-1">
                  <div class="flex rounded-md shadow-sm">
                    <div class="relative flex-grow items-stretch focus-within:z-10">
                      <input
                        type="text"
                        class="w-full rounded-none rounded-l-md border-gray-300 bg-gray-100"
                        value={@form[:supplier_name].value}
                        readonly="readonly"
                      />
                    </div>
                    <button
                      type="button"
                      class="relative -ml-px inline-flex items-center space-x-2 rounded-r-md border border-gray-300 bg-gray-50 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
                      phx-click="open_supplier_search"
                    >
                      <span>Търси</span>
                    </button>
                  </div>
                </div>
              </div>
              <.input field={@form[:supplier_name]} label="Име за фактура" />
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
                    <%= for {line, index} <- Enum.with_index(@order_lines) do %>
                      <tr>
                        <td class="px-3 py-2">
                          <div class="flex rounded-md shadow-sm">
                            <input
                              type="text"
                              class="w-full rounded-none rounded-l-md border-gray-300 bg-gray-100"
                              value={get_product_name(@products, line.product_id)}
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
                          <input
                            type="text"
                            name={"lines[#{index}][description]"}
                            value={line.description}
                            class="w-full rounded-md border-gray-300 text-sm"
                            phx-debounce="300"
                            phx-change="update_lines"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            step="0.01"
                            name={"lines[#{index}][quantity]"}
                            value={line.quantity}
                            class="w-24 rounded-md border-gray-300 text-right text-sm"
                            phx-change="update_lines"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            step="0.01"
                            name={"lines[#{index}][unit_price]"}
                            value={line.unit_price}
                            class="w-28 rounded-md border-gray-300 text-right text-sm"
                            phx-change="update_lines"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            step="0.01"
                            name={"lines[#{index}][discount_percent]"}
                            value={line.discount_percent}
                            class="w-24 rounded-md border-gray-300 text-right text-sm"
                            phx-change="update_lines"
                          />
                        </td>
                        <td class="px-3 py-2">
                          <input
                            type="number"
                            step="0.01"
                            name={"lines[#{index}][tax_rate]"}
                            value={line.tax_rate}
                            class="w-24 rounded-md border-gray-300 text-right text-sm"
                            phx-change="update_lines"
                          />
                        </td>
                        <td class="px-3 py-2 text-right">
                          <button type="button" phx-click="remove_line" phx-value-index={index} class="text-xs text-red-500 hover:text-red-600">
                            Премахни
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex justify-end gap-8 text-sm">
                <div>
                  <div class="text-gray-500">Междинна сума</div>
                  <div class="text-right font-medium text-gray-900"><%= format_money(@order_totals.subtotal) %></div>
                </div>
                <div>
                  <div class="text-gray-500">ДДС</div>
                  <div class="text-right font-medium text-gray-900"><%= format_money(@order_totals.tax) %></div>
                </div>
                <div>
                  <div class="text-gray-500">Общо</div>
                  <div class="text-right text-lg font-semibold text-gray-900"><%= format_money(@order_totals.total) %></div>
                </div>
              </div>
            </div>

            <.input field={@form[:notes]} type="textarea" label="Бележки" rows={3} />

            <:actions>
              <.button type="submit">Запази</.button>
              <.link patch={~p"/purchase-orders"} class="text-sm text-gray-500 hover:text-gray-700">Отказ</.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="supplier-search-modal"
      show={@show_supplier_search_modal}
      title="Търсене на доставчик"
      search_fun={&CyberCore.Contacts.search_contacts(@tenant_id, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:vat_number, "text-sm text-gray-600", fn v -> "ДДС: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:supplier_id}
    />

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="product-search-modal"
      show={@show_product_search_modal}
      title="Търсене на продукт"
      search_fun={&CyberCore.Inventory.search_products(@tenant_id, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:sku, "text-sm text-gray-600", fn v -> "SKU: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:product_id}
    />
    """
  end

  defp status_options do
    [
      {"Чернова", "draft"},
      {"Приключен", "received"}
    ]
  end

  defp humanize_status("draft"), do: "Чернова"
  defp humanize_status("sent"), do: "Изпратена"
  defp humanize_status("confirmed"), do: "Потвърдена"
  defp humanize_status("receiving"), do: "Приемане"
  defp humanize_status("received"), do: "Приключен"
  defp humanize_status("cancelled"), do: "Отказана"
  defp humanize_status(status), do: String.capitalize(status)

  defp status_badge("draft"),
    do: "inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600"

  defp status_badge("sent"),
    do: "inline-flex rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-600"

  defp status_badge("confirmed"),
    do: "inline-flex rounded-full bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-600"

  defp status_badge("receiving"),
    do: "inline-flex rounded-full bg-amber-100 px-2 py-1 text-xs font-medium text-amber-600"

  defp status_badge("received"),
    do: "inline-flex rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-600"

  defp status_badge("cancelled"),
    do: "inline-flex rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-600"

  defp status_badge(_),
    do: "inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600"

  defp format_money(nil), do: "0.00"

  defp format_money(%Decimal{} = amount) do
    amount
    |> D.round(2)
    |> D.to_string(:normal)
    |> format_decimal_string()
  end

  defp format_money(amount) when is_binary(amount), do: amount

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

  defp format_decimal_string(value) do
    case String.split(value, ".") do
      [whole, decimals] ->
        padded = decimals |> String.pad_trailing(2, "0") |> String.slice(0, 2)
        whole <> "." <> padded

      [whole] ->
        whole <> ".00"
    end
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp get_product_name(products, product_id) do
    case Enum.find(products, &(&1.id == product_id)) do
      nil -> ""
      product -> product.name
    end
  end
end
