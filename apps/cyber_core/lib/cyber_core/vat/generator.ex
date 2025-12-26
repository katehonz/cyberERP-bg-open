defmodule CyberCore.Vat.Generator do
  @moduledoc """
  This module provides functions for generating VAT declaration files.
  """

  alias CyberCore.Repo
  alias CyberCore.Sales.Invoice
  alias CyberCore.Purchase.SupplierInvoice
  import Ecto.Query

  def generate_prodagbi_txt(tenant_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    invoices =
      from(
        i in Invoice,
        where:
          i.tenant_id == ^tenant_id and i.issue_date >= ^start_date and
            i.issue_date <= ^end_date,
        preload: [:contact]
      )
      |> Repo.all()

    invoices
    |> Enum.with_index(1)
    |> Enum.map_join("\r\n", fn {invoice, index} -> format_prodagbi_line({invoice, index + 1}) end)
  end

  def generate_pokupki_txt(tenant_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    invoices =
      from(
        i in SupplierInvoice,
        where:
          i.tenant_id == ^tenant_id and i.invoice_date >= ^start_date and
            i.invoice_date <= ^end_date,
        preload: [:supplier]
      )
      |> Repo.all()

    invoices
    |> Enum.with_index(1)
    |> Enum.map_join("\r\n", fn {invoice, index} -> format_pokupki_line({invoice, index + 1}) end)
  end

  defp format_prodagbi_line({invoice, index}) do
    [
      format_field(invoice.tenant_id, 15),
      format_field(format_period(invoice.issue_date), 6),
      format_field(0, 4, :numeric),
      format_field(index, 15, :numeric),
      format_field(invoice.vat_document_type || "01", 2),
      format_field(invoice.invoice_no, 20),
      format_field(format_date(invoice.issue_date), 10),
      format_field(invoice.contact.vat_number, 15),
      format_field(invoice.contact.name, 50),
      format_field("Предмет на доставката", 30),
      format_field(invoice.subtotal, 15, :numeric),
      format_field(invoice.tax_amount, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 2)
    ]
    |> Enum.join("")
  end

  defp format_pokupki_line({invoice, index}) do
    [
      format_field(invoice.tenant_id, 15),
      format_field(format_period(invoice.invoice_date), 6),
      format_field(0, 4, :numeric),
      format_field(index, 15, :numeric),
      format_field(invoice.vat_document_type || "01", 2),
      format_field(invoice.supplier_invoice_no, 20),
      format_field(format_date(invoice.invoice_date), 10),
      format_field(invoice.supplier.vat_number, 15),
      format_field(invoice.supplier.name, 50),
      format_field("Предмет на доставката", 30),
      format_field(invoice.subtotal, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(invoice.tax_amount, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric),
      format_field(0, 15, :numeric)
    ]
    |> Enum.join("")
  end

  defp format_field(value, length, type \\ :symbolic) do
    string_value =
      cond do
        is_nil(value) ->
          ""

        type == :numeric and is_integer(value) ->
          Decimal.new(value) |> Decimal.to_string(:normal)

        type == :numeric ->
          Decimal.to_string(value, :normal)

        true ->
          to_string(value)
      end

    if String.length(string_value) > length do
      String.slice(string_value, 0, length)
    else
      if type == :numeric do
        String.pad_leading(string_value, length, " ")
      else
        String.pad_trailing(string_value, length, " ")
      end
    end
  end

  defp format_date(date) do
    {year, month, day} = Date.to_erl(date)

    "#{String.pad_leading(to_string(day), 2, "0")}/#{String.pad_leading(to_string(month), 2, "0")}/#{year}"
  end

  defp format_period(date) do
    {year, month, _day} = Date.to_erl(date)
    "#{year}#{String.pad_leading(to_string(month), 2, "0")}"
  end
end
