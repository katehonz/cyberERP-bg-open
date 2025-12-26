defmodule CyberWeb.InvoiceJSON do
  @moduledoc """
  JSON сериализация за Invoice ресурс.
  """

  alias CyberCore.Sales.{Invoice, InvoiceLine}

  @doc """
  Рендерира списък от фактури.
  """
  def index(%{invoices: invoices}) do
    %{data: for(invoice <- invoices, do: data(invoice))}
  end

  @doc """
  Рендерира една фактура.
  """
  def show(%{invoice: invoice}) do
    %{data: data(invoice)}
  end

  defp data(%Invoice{} = invoice) do
    base_data = %{
      id: invoice.id,
      tenant_id: invoice.tenant_id,
      contact_id: invoice.contact_id,
      invoice_no: invoice.invoice_no,
      invoice_type: invoice.invoice_type,
      status: invoice.status,
      issue_date: invoice.issue_date,
      due_date: invoice.due_date,
      tax_event_date: invoice.tax_event_date,
      billing_name: invoice.billing_name,
      billing_address: invoice.billing_address,
      billing_vat_number: invoice.billing_vat_number,
      billing_company_id: invoice.billing_company_id,
      subtotal: invoice.subtotal,
      tax_amount: invoice.tax_amount,
      total_amount: invoice.total_amount,
      paid_amount: invoice.paid_amount,
      currency: invoice.currency,
      notes: invoice.notes,
      payment_terms: invoice.payment_terms,
      reference: invoice.reference,
      parent_invoice_id: invoice.parent_invoice_id,
      inserted_at: invoice.inserted_at,
      updated_at: invoice.updated_at
    }

    # Добавяме invoice_lines ако са заредени
    if Ecto.assoc_loaded?(invoice.invoice_lines) do
      Map.put(base_data, :invoice_lines, Enum.map(invoice.invoice_lines, &line_data/1))
    else
      base_data
    end
  end

  defp line_data(%InvoiceLine{} = line) do
    %{
      id: line.id,
      product_id: line.product_id,
      description: line.description,
      quantity: line.quantity,
      unit_price: line.unit_price,
      discount_percent: line.discount_percent,
      discount_amount: line.discount_amount,
      tax_rate: line.tax_rate,
      subtotal: line.subtotal,
      tax_amount: line.tax_amount,
      total_amount: line.total_amount,
      notes: line.notes
    }
  end
end
