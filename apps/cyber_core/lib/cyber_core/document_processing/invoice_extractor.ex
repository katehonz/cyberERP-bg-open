defmodule CyberCore.DocumentProcessing.InvoiceExtractor do
  @moduledoc """
  Извлича данни от Azure Form Recognizer резултати и ги преобразува в ExtractedInvoice формат.

  Azure Form Recognizer връща структуриран JSON с извлечени полета от фактурата.
  """

  require Logger

  @doc """
  Парсва Azure Form Recognizer резултат и създава ExtractedInvoice атрибути.

  ## Parameters
  - `azure_result` - JSON резултат от Azure Form Recognizer
  - `tenant_id` - ID на tenant
  - `document_upload_id` - ID на качения документ
  - `invoice_type` - "sales" или "purchase"

  ## Returns
  - `{:ok, attrs}` - атрибути за създаване на ExtractedInvoice
  - `{:error, reason}` - грешка при парсване
  """
  def extract_invoice_data(azure_result, tenant_id, document_upload_id, invoice_type) do
    try do
      documents = get_in(azure_result, ["documents"]) || []

      if length(documents) == 0 do
        {:error, "No documents found in Azure result"}
      else
        # Вземаме първия документ (при batch може да има повече)
        document = List.first(documents)

        attrs = %{
          tenant_id: tenant_id,
          document_upload_id: document_upload_id,
          invoice_type: invoice_type,
          confidence_score: get_confidence(document),
          invoice_number: extract_field(document, "InvoiceId"),
          invoice_date: extract_date_field(document, "InvoiceDate"),
          due_date: extract_date_field(document, "DueDate"),
          vendor_name: extract_vendor_field(document, "VendorName"),
          vendor_address: extract_vendor_field(document, "VendorAddress"),
          vendor_vat_number: extract_vendor_field(document, "VendorTaxId"),
          customer_name: extract_customer_field(document, "CustomerName"),
          customer_address: extract_customer_field(document, "CustomerAddress"),
          customer_vat_number: extract_customer_field(document, "CustomerTaxId"),
          subtotal: extract_amount_field(document, "SubTotal"),
          tax_amount: extract_amount_field(document, "TotalTax"),
          total_amount: extract_amount_field(document, "InvoiceTotal"),
          currency: extract_currency(document),
          line_items: extract_line_items(document),
          raw_data: azure_result
        }

        {:ok, attrs}
      end
    rescue
      error ->
        Logger.error("Failed to extract invoice data: #{inspect(error)}")
        {:error, "Failed to parse Azure result: #{inspect(error)}"}
    end
  end

  # Private helper functions

  defp get_confidence(document) do
    confidence = get_in(document, ["confidence"])

    if confidence do
      # Convert float to Decimal using cast
      case Decimal.cast(confidence) do
        {:ok, decimal} -> decimal
        _ -> Decimal.new("0.0")
      end
    else
      Decimal.new("0.0")
    end
  end

  defp extract_field(document, field_name) do
    fields = get_in(document, ["fields"]) || %{}
    field = Map.get(fields, field_name)

    if field do
      get_in(field, ["content"]) || get_in(field, ["valueString"])
    end
  end

  defp extract_date_field(document, field_name) do
    fields = get_in(document, ["fields"]) || %{}
    field = Map.get(fields, field_name)

    if field do
      # Azure може да върне дата в ISO формат или като valueDate
      date_value = get_in(field, ["valueDate"]) || get_in(field, ["content"])

      if date_value do
        case Date.from_iso8601(date_value) do
          {:ok, date} -> date
          _ -> nil
        end
      end
    end
  end

  defp extract_vendor_field(document, field_name) do
    fields = get_in(document, ["fields"]) || %{}
    vendor_fields = get_in(fields, ["VendorAddressRecipient", "fields"]) || fields

    field = Map.get(vendor_fields, field_name)

    if field do
      get_in(field, ["content"]) || get_in(field, ["valueString"]) ||
        get_in(field, ["valueAddress"])
    end
  end

  defp extract_customer_field(document, field_name) do
    fields = get_in(document, ["fields"]) || %{}
    customer_fields = get_in(fields, ["CustomerAddressRecipient", "fields"]) || fields

    field = Map.get(customer_fields, field_name)

    if field do
      get_in(field, ["content"]) || get_in(field, ["valueString"]) ||
        get_in(field, ["valueAddress"])
    end
  end

  defp extract_amount_field(document, field_name) do
    fields = get_in(document, ["fields"]) || %{}
    field = Map.get(fields, field_name)

    if field do
      amount = get_in(field, ["valueCurrency", "amount"]) || get_in(field, ["valueNumber"])

      if amount do
        case Decimal.cast(amount) do
          {:ok, decimal} -> decimal
          _ -> nil
        end
      end
    end
  end

  defp extract_currency(document) do
    fields = get_in(document, ["fields"]) || %{}

    # Проверяваме InvoiceTotal за валута
    invoice_total = Map.get(fields, "InvoiceTotal")

    if invoice_total do
      currency_code = get_in(invoice_total, ["valueCurrency", "currencyCode"])

      if currency_code do
        String.upcase(currency_code)
      else
        "BGN"
      end
    else
      "BGN"
    end
  end

  defp extract_line_items(document) do
    fields = get_in(document, ["fields"]) || %{}
    items_field = Map.get(fields, "Items")

    if items_field do
      items = get_in(items_field, ["valueArray"]) || []

      Enum.map(items, fn item ->
        item_fields = get_in(item, ["fields"]) || %{}

        %{
          description: get_item_field(item_fields, "Description"),
          quantity: parse_decimal(get_item_field(item_fields, "Quantity")),
          unit_price: parse_decimal(get_item_field(item_fields, "UnitPrice")),
          amount: parse_decimal(get_item_field(item_fields, "Amount")),
          tax: parse_decimal(get_item_field(item_fields, "Tax"))
        }
      end)
    else
      []
    end
  end

  defp get_item_field(fields, field_name) do
    field = Map.get(fields, field_name)

    if field do
      get_in(field, ["content"]) ||
        get_in(field, ["valueString"]) ||
        get_in(field, ["valueNumber"]) ||
        to_string(get_in(field, ["valueCurrency", "amount"]))
    end
  end

  defp parse_decimal(nil), do: nil

  defp parse_decimal(value) when is_number(value) do
    case Decimal.cast(value) do
      {:ok, decimal} -> decimal
      _ -> nil
    end
  end

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp parse_decimal(_), do: nil
end
