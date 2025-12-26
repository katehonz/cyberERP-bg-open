defmodule CyberWeb.PurchaseOrderJSON do
  @moduledoc """
  JSON сериализация за PurchaseOrder ресурс.
  """

  alias CyberCore.Purchase.{PurchaseOrder, PurchaseOrderLine}

  @doc """
  Рендерира списък от поръчки за покупка.
  """
  def index(%{purchase_orders: purchase_orders}) do
    %{data: for(po <- purchase_orders, do: data(po))}
  end

  @doc """
  Рендерира една поръчка за покупка.
  """
  def show(%{purchase_order: purchase_order}) do
    %{data: data(purchase_order)}
  end

  defp data(%PurchaseOrder{} = po) do
    base_data = %{
      id: po.id,
      tenant_id: po.tenant_id,
      supplier_id: po.supplier_id,
      order_no: po.order_no,
      status: po.status,
      order_date: po.order_date,
      expected_date: po.expected_date,
      received_date: po.received_date,
      supplier_name: po.supplier_name,
      supplier_address: po.supplier_address,
      supplier_vat_number: po.supplier_vat_number,
      subtotal: po.subtotal,
      tax_amount: po.tax_amount,
      total_amount: po.total_amount,
      currency: po.currency,
      notes: po.notes,
      payment_terms: po.payment_terms,
      reference: po.reference,
      inserted_at: po.inserted_at,
      updated_at: po.updated_at
    }

    # Добавяме purchase_order_lines ако са заредени
    if Ecto.assoc_loaded?(po.purchase_order_lines) do
      Map.put(base_data, :purchase_order_lines, Enum.map(po.purchase_order_lines, &line_data/1))
    else
      base_data
    end
  end

  defp line_data(%PurchaseOrderLine{} = line) do
    %{
      id: line.id,
      product_id: line.product_id,
      line_no: line.line_no,
      description: line.description,
      quantity_ordered: line.quantity_ordered,
      quantity_received: line.quantity_received,
      unit_of_measure: line.unit_of_measure,
      unit_price: line.unit_price,
      discount_percent: line.discount_percent,
      tax_rate: line.tax_rate,
      subtotal: line.subtotal,
      tax_amount: line.tax_amount,
      total_amount: line.total_amount,
      notes: line.notes
    }
  end
end
