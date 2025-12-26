defmodule CyberCore.Purchase do
  @moduledoc """
  Контекст за покупки и управление на доставчици.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo

  alias CyberCore.Purchase.{
    PurchaseOrder,
    PurchaseOrderLine,
    SupplierInvoice,
    SupplierInvoiceLine
  }

  # -- Purchase Orders --

  def list_purchase_orders(tenant_id, opts \\ []) do
    query = 
      from po in PurchaseOrder,
        where: po.tenant_id == ^tenant_id,
        order_by: [desc: po.order_date],
        preload: [:supplier]

    Repo.all(apply_po_filters(query, opts))
  end

  def get_purchase_order!(tenant_id, id, preloads \\ [:supplier, :purchase_order_lines]) do
    PurchaseOrder
    |> where([po], po.tenant_id == ^tenant_id and po.id == ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  def create_purchase_order(attrs) do
    %PurchaseOrder{}
    |> PurchaseOrder.changeset(attrs)
    |> Repo.insert()
  end

  def create_purchase_order_with_lines(order_attrs, lines_attrs) when is_list(lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, order} <- create_purchase_order(order_attrs),
           {:ok, lines} <- insert_purchase_order_lines(order, lines_attrs),
           {:ok, updated_order} <- update_order_totals(order, lines) do
        Repo.preload(updated_order, [:supplier, :purchase_order_lines])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_purchase_order(%PurchaseOrder{} = order, attrs) do
    order
    |> PurchaseOrder.changeset(attrs)
    |> Repo.update()
  end

  def delete_purchase_order(%PurchaseOrder{} = order), do: Repo.delete(order)

  def change_purchase_order(%PurchaseOrder{} = order, attrs \\ %{}) do
    PurchaseOrder.changeset(order, attrs)
  end

  defp insert_purchase_order_lines(%PurchaseOrder{} = order, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.put(attrs, :tenant_id, order.tenant_id)
      attrs = Map.put(attrs, :purchase_order_id, order.id)

      %PurchaseOrderLine{}
      |> PurchaseOrderLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp update_order_totals(%PurchaseOrder{} = order, lines) do
    subtotal = 
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.subtotal)
      end)

    tax_amount = 
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.tax_amount)
      end)

    total_amount = 
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.total_amount)
      end)

    update_purchase_order(order, %{
      subtotal: subtotal,
      tax_amount: tax_amount,
      total_amount: total_amount
    })
  end

  defp apply_po_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] ->
        acc

      {:status, status}, acc ->
        from po in acc, where: po.status == ^status

      {:supplier_id, id}, acc when is_integer(id) ->
        from po in acc, where: po.supplier_id == ^id

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from po in acc, where: po.order_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from po in acc, where: po.order_date <= ^date
          _ -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"
        from po in acc, where: ilike(po.order_no, ^pattern) or ilike(po.supplier_name, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Supplier Invoices --

  def list_supplier_invoices(tenant_id, opts \\ []) do
    query = 
      from si in SupplierInvoice,
        where: si.tenant_id == ^tenant_id,
        order_by: [desc: si.invoice_date],
        preload: [:supplier, :purchase_order]

    Repo.all(apply_si_filters(query, opts))
  end

  def get_supplier_invoice!(tenant_id, id, preloads \\ [:supplier, :supplier_invoice_lines]) do
    SupplierInvoice
    |> where([si], si.tenant_id == ^tenant_id and si.id == ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  def create_supplier_invoice(attrs) do
    %SupplierInvoice{}
    |> SupplierInvoice.changeset(attrs)
    |> Repo.insert()
  end

  def create_supplier_invoice_with_lines(invoice_attrs, lines_attrs) when is_list(lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, invoice} <- create_supplier_invoice(invoice_attrs),
           {:ok, lines} <- insert_supplier_invoice_lines(invoice, lines_attrs),
           {:ok, updated_invoice} <- update_invoice_totals(invoice, lines) do
        
        # Update the supplier price list
        update_supplier_price_list(updated_invoice)

        Repo.preload(updated_invoice, [:supplier, :supplier_invoice_lines])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_supplier_invoice(%SupplierInvoice{} = invoice, attrs) do
    invoice
    |> SupplierInvoice.changeset(attrs)
    |> Repo.update()
  end

  def delete_supplier_invoice(%SupplierInvoice{} = invoice), do: Repo.delete(invoice)

  def change_supplier_invoice(%SupplierInvoice{} = invoice, attrs \\ %{}) do
    SupplierInvoice.changeset(invoice, attrs)
  end

  defp insert_supplier_invoice_lines(%SupplierInvoice{} = invoice, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.put(attrs, :tenant_id, invoice.tenant_id)
      attrs = Map.put(attrs, :supplier_invoice_id, invoice.id)

      %SupplierInvoiceLine{}
      |> SupplierInvoiceLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp update_invoice_totals(%SupplierInvoice{} = invoice, lines) do
    subtotal =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.subtotal)
      end)

    tax_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.tax_amount)
      end)

    total_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.total_amount)
      end)

    update_supplier_invoice(invoice, %{
      subtotal: subtotal,
      tax_amount: tax_amount,
      total_amount: total_amount
    })
  end

  defp update_supplier_price_list(invoice) do
    invoice = Repo.preload(invoice, [:supplier, :supplier_invoice_lines])
    supplier = invoice.supplier
    tenant_id = invoice.tenant_id
  
    price_list = 
      case CyberCore.Sales.PriceLists.get_price_list(supplier.price_list_id) do
        nil ->
          default_currency_code = CyberCore.Settings.get_default_currency(tenant_id)
          default_currency = Repo.get_by!(CyberCore.Currencies.Currency, code: default_currency_code)
          {:ok, pl} = CyberCore.Sales.PriceLists.create_price_list(%{
            name: "Автоматична - " <> supplier.name,
            type: "non_retail",
            tenant_id: tenant_id,
            currency_id: default_currency.id
          })
          {:ok, _} = CyberCore.Contacts.update_contact(supplier, %{price_list_id: pl.id})
          pl
        price_list -> price_list
      end
  
    for line <- invoice.supplier_invoice_lines do
      if line.product_id && line.unit_price do
        existing_item = CyberCore.Sales.PriceLists.get_item_by_product(price_list.id, line.product_id)
        
        attrs = %{
          price_list_id: price_list.id,
          product_id: line.product_id,
          price: line.unit_price
        }
  
        if existing_item do
          CyberCore.Sales.PriceLists.update_price_list_item(existing_item, attrs)
        else
          CyberCore.Sales.PriceLists.create_price_list_item(attrs)
        end
      end
    end
    
    :ok
  end

  defp apply_si_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] ->
        acc

      {:status, status}, acc ->
        from si in acc, where: si.status == ^status

      {:supplier_id, id}, acc when is_integer(id) ->
        from si in acc, where: si.supplier_id == ^id

      {:purchase_order_id, id}, acc when is_integer(id) ->
        from si in acc, where: si.purchase_order_id == ^id

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from si in acc, where: si.invoice_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from si in acc, where: si.invoice_date <= ^date
          _ -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"
        from si in acc, where: ilike(si.invoice_no, ^pattern) or ilike(si.supplier_name, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Helper functions --

  defp handle_batch_result(results) do
    case Enum.split_with(results, fn
           {:ok, _} -> true
           _ -> false
         end) do
      {oks, []} -> {:ok, Enum.map(oks, fn {:ok, record} -> record end)}
      {_, [{:error, changeset} | _]} -> {:error, changeset}
    end
  end
end