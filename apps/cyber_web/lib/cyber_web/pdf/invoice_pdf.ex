defmodule CyberWeb.Pdf.InvoicePdf do
  alias CyberCore.Sales.Invoice

  def generate(params) do
    lines_with_totals =
      (params["lines"] || [])
      |> Enum.map(fn line ->
        qty = to_decimal(line["quantity"])
        price = to_decimal(line["unit_price"])
        discount_percent = to_decimal(line["discount_percent"] || 0)
        tax_rate = to_decimal(line["tax_rate"])

        gross_amount = Decimal.mult(qty, price)
        discount_amount = Decimal.mult(gross_amount, Decimal.div(discount_percent, 100))
        subtotal = Decimal.sub(gross_amount, discount_amount)
        tax_amount = Decimal.mult(subtotal, Decimal.div(tax_rate, 100))

        line
        |> Map.put("subtotal_str", Decimal.to_string(subtotal, :normal))
        |> Map.put("subtotal_dec", subtotal)
        |> Map.put("tax_amount_dec", tax_amount)
      end)

    total_subtotal =
      Enum.reduce(lines_with_totals, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line["subtotal_dec"])
      end)

    total_tax =
      Enum.reduce(lines_with_totals, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line["tax_amount_dec"])
      end)

    grand_total = Decimal.add(total_subtotal, total_tax)

    invoice_data =
      params
      |> Map.put("lines", lines_with_totals)
      |> Map.put("subtotal", Decimal.to_string(total_subtotal, :normal))
      |> Map.put("tax_amount", Decimal.to_string(total_tax, :normal))
      |> Map.put("total_amount", Decimal.to_string(grand_total, :normal))

    title = get_title(Map.get(params, "vat_document_type"))
    assigns = [invoice: invoice_data, title: title]

    template_path =
      Path.expand("apps/cyber_web/lib/cyber_web/pdf/invoice_pdf.html.eex", File.cwd!())

    try do
      html = EEx.eval_file(template_path, assigns)

      PdfGenerator.generate(html,
        page_size: "A4",
        margin_top: "1cm",
        margin_bottom: "1cm",
        margin_left: "1cm",
        margin_right: "1cm",
        binary: true
      )
    catch
      e, r -> {:error, "Failed to render template: #{inspect(e)} #{inspect(r)}"}
    end
  end

  defp get_title(type_code) do
    Map.get(Invoice.vat_document_types(), type_code, "Фактура")
  end

  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(%Decimal{} = value), do: value

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(_value), do: Decimal.new(0)
end
