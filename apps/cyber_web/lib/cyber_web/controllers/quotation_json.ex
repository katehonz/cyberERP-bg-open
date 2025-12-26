defmodule CyberWeb.QuotationJSON do
  @moduledoc """
  JSON сериализация за Quotation ресурс.
  """

  alias CyberCore.Sales.{Quotation, QuotationLine}

  @doc """
  Рендерира списък от оферти.
  """
  def index(%{quotations: quotations}) do
    %{data: for(quotation <- quotations, do: data(quotation))}
  end

  @doc """
  Рендерира една оферта.
  """
  def show(%{quotation: quotation}) do
    %{data: data(quotation)}
  end

  defp data(%Quotation{} = quotation) do
    base_data = %{
      id: quotation.id,
      tenant_id: quotation.tenant_id,
      contact_id: quotation.contact_id,
      quotation_no: quotation.quotation_no,
      status: quotation.status,
      issue_date: quotation.issue_date,
      valid_until: quotation.valid_until,
      contact_name: quotation.contact_name,
      contact_email: quotation.contact_email,
      contact_phone: quotation.contact_phone,
      subtotal: quotation.subtotal,
      tax_amount: quotation.tax_amount,
      total_amount: quotation.total_amount,
      currency: quotation.currency,
      notes: quotation.notes,
      terms_and_conditions: quotation.terms_and_conditions,
      invoice_id: quotation.invoice_id,
      inserted_at: quotation.inserted_at,
      updated_at: quotation.updated_at
    }

    # Добавяме quotation_lines ако са заредени
    if Ecto.assoc_loaded?(quotation.quotation_lines) do
      Map.put(base_data, :quotation_lines, Enum.map(quotation.quotation_lines, &line_data/1))
    else
      base_data
    end
  end

  defp line_data(%QuotationLine{} = line) do
    %{
      id: line.id,
      product_id: line.product_id,
      line_no: line.line_no,
      description: line.description,
      quantity: line.quantity,
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
