defmodule CyberCore.SAFT.GeneralLedgerEntries do
  @moduledoc """
  Генерира GeneralLedgerEntries секцията на SAF-T файла.

  Съдържа всички счетоводни записи (журнални статии) за периода.
  """

  import Ecto.Query
  alias CyberCore.Repo

  @doc """
  Изгражда GeneralLedgerEntries секцията.
  """
  def build(tenant_id, opts \\ []) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)

    entries = get_journal_entries(tenant_id, year, month)
    {total_debit, total_credit} = calculate_totals(entries)
    number_of_entries = length(entries)

    entries_xml =
      entries
      |> Enum.map(&build_journal_entry/1)
      |> Enum.join("\n")

    # GeneralLedgerEntries е задължителен елемент и трябва поне един Journal
    journal_placeholder =
      if Enum.empty?(entries) do
        """
            <nsSAFT:Journal>
              <nsSAFT:JournalID>GJ</nsSAFT:JournalID>
              <nsSAFT:Description>Главен журнал</nsSAFT:Description>
              <nsSAFT:Type>GJ</nsSAFT:Type>
              <nsSAFT:Transaction>
                <nsSAFT:TransactionID>0</nsSAFT:TransactionID>
                <nsSAFT:Period>#{month}</nsSAFT:Period>
                <nsSAFT:PeriodYear>#{year}</nsSAFT:PeriodYear>
                <nsSAFT:TransactionDate>#{Date.new!(year, month, 1) |> Date.to_iso8601()}</nsSAFT:TransactionDate>
                <nsSAFT:Description>Няма записи за периода</nsSAFT:Description>
                <nsSAFT:SystemEntryDate>#{Date.utc_today() |> Date.to_iso8601()}</nsSAFT:SystemEntryDate>
                <nsSAFT:GLPostingDate>#{Date.new!(year, month, 1) |> Date.to_iso8601()}</nsSAFT:GLPostingDate>
                <nsSAFT:CustomerID></nsSAFT:CustomerID>
                <nsSAFT:SupplierID></nsSAFT:SupplierID>
                <nsSAFT:TransactionLine>
                  <nsSAFT:RecordID>0</nsSAFT:RecordID>
                  <nsSAFT:AccountID>100</nsSAFT:AccountID>
                  <nsSAFT:TaxpayerAccountID>100</nsSAFT:TaxpayerAccountID>
                  <nsSAFT:CustomerID></nsSAFT:CustomerID>
                  <nsSAFT:SupplierID></nsSAFT:SupplierID>
                  <nsSAFT:Description>Няма записи</nsSAFT:Description>
                  <nsSAFT:DebitAmount>
                    <nsSAFT:Amount>0.00</nsSAFT:Amount>
                    <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                    <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                    <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                  </nsSAFT:DebitAmount>
                  <nsSAFT:TaxInformation>
                    <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                    <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
                    <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
                    <nsSAFT:TaxBase>0.00</nsSAFT:TaxBase>
                    <nsSAFT:TaxAmount>
                      <nsSAFT:Amount>0.00</nsSAFT:Amount>
                      <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                      <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                      <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                    </nsSAFT:TaxAmount>
                  </nsSAFT:TaxInformation>
                </nsSAFT:TransactionLine>
              </nsSAFT:Transaction>
            </nsSAFT:Journal>
        """
      else
        entries_xml
      end

    content = """
      <nsSAFT:GeneralLedgerEntries>
        <nsSAFT:NumberOfEntries>#{number_of_entries}</nsSAFT:NumberOfEntries>
        <nsSAFT:TotalDebit>#{format_decimal(total_debit)}</nsSAFT:TotalDebit>
        <nsSAFT:TotalCredit>#{format_decimal(total_credit)}</nsSAFT:TotalCredit>
    #{journal_placeholder}
      </nsSAFT:GeneralLedgerEntries>
    """

    {:ok, content}
  end

  defp build_journal_entry(entry) do
    lines_xml =
      entry.lines
      |> Enum.map(&build_line/1)
      |> Enum.join("\n")

    """
          <nsSAFT:Journal>
            <nsSAFT:JournalID>#{entry.journal_type || "GJ"}</nsSAFT:JournalID>
            <nsSAFT:Description>#{escape_xml(entry.journal_description || "Главен журнал")}</nsSAFT:Description>
            <nsSAFT:Type>#{entry.journal_type || "GJ"}</nsSAFT:Type>
            <nsSAFT:Transaction>
              <nsSAFT:TransactionID>#{entry.id}</nsSAFT:TransactionID>
              <nsSAFT:Period>#{entry.period || get_month(entry.date)}</nsSAFT:Period>
              <nsSAFT:PeriodYear>#{entry.period_year || get_year(entry.date)}</nsSAFT:PeriodYear>
              <nsSAFT:TransactionDate>#{format_date(entry.date)}</nsSAFT:TransactionDate>
              <nsSAFT:SourceID>#{entry.created_by || "system"}</nsSAFT:SourceID>
              <nsSAFT:TransactionType>#{entry.transaction_type || "N"}</nsSAFT:TransactionType>
              <nsSAFT:Description>#{escape_xml(entry.description || "")}</nsSAFT:Description>
              <nsSAFT:SystemEntryDate>#{format_date(entry.inserted_at)}</nsSAFT:SystemEntryDate>
              <nsSAFT:GLPostingDate>#{format_date(entry.posted_at || entry.date)}</nsSAFT:GLPostingDate>
    #{lines_xml}
            </nsSAFT:Transaction>
          </nsSAFT:Journal>
    """
  end

  defp build_line(line) do
    is_debit = Decimal.gt?(line.debit || Decimal.new(0), Decimal.new(0))

    """
              <nsSAFT:Line>
                <nsSAFT:RecordID>#{line.id}</nsSAFT:RecordID>
                <nsSAFT:AccountID>#{line.account_code}</nsSAFT:AccountID>
                <nsSAFT:SourceDocumentID>#{line.source_document_id || ""}</nsSAFT:SourceDocumentID>
    #{build_customer_supplier_id(line)}
                <nsSAFT:Description>#{escape_xml(line.description || "")}</nsSAFT:Description>
    #{if is_debit, do: build_debit_amount(line), else: build_credit_amount(line)}
    #{build_tax_information(line)}
              </nsSAFT:Line>
    """
  end

  defp build_customer_supplier_id(line) do
    cond do
      line.customer_id ->
        "            <nsSAFT:CustomerID>#{line.customer_id}</nsSAFT:CustomerID>"

      line.supplier_id ->
        "            <nsSAFT:SupplierID>#{line.supplier_id}</nsSAFT:SupplierID>"

      true ->
        ""
    end
  end

  defp build_debit_amount(line) do
    amount = line.debit || Decimal.new(0)

    """
                <nsSAFT:DebitAmount>
                  <nsSAFT:Amount>#{format_decimal(amount)}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(line.currency_amount || amount)}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>#{format_decimal(line.exchange_rate || Decimal.new(1))}</nsSAFT:ExchangeRate>
                </nsSAFT:DebitAmount>
    """
  end

  defp build_credit_amount(line) do
    amount = line.credit || Decimal.new(0)

    """
                <nsSAFT:CreditAmount>
                  <nsSAFT:Amount>#{format_decimal(amount)}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(line.currency_amount || amount)}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>#{format_decimal(line.exchange_rate || Decimal.new(1))}</nsSAFT:ExchangeRate>
                </nsSAFT:CreditAmount>
    """
  end

  defp build_tax_information(line) do
    if line.vat_amount && Decimal.gt?(line.vat_amount, Decimal.new(0)) do
      """
                <nsSAFT:TaxInformation>
                  <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                  <nsSAFT:TaxCode>#{line.vat_rate || "20"}</nsSAFT:TaxCode>
                  <nsSAFT:TaxPercentage>#{format_decimal(line.vat_rate || Decimal.new(20))}</nsSAFT:TaxPercentage>
                  <nsSAFT:TaxBase>#{format_decimal(line.tax_base || line.debit || line.credit)}</nsSAFT:TaxBase>
                  <nsSAFT:TaxAmount>
                    <nsSAFT:Amount>#{format_decimal(line.vat_amount)}</nsSAFT:Amount>
                    <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                    <nsSAFT:CurrencyAmount>#{format_decimal(line.vat_amount)}</nsSAFT:CurrencyAmount>
                    <nsSAFT:ExchangeRate>#{format_decimal(line.exchange_rate || Decimal.new(1))}</nsSAFT:ExchangeRate>
                  </nsSAFT:TaxAmount>
                </nsSAFT:TaxInformation>
      """
    else
      ""
    end
  end

  defp calculate_totals(entries) do
    entries
    |> Enum.reduce({Decimal.new(0), Decimal.new(0)}, fn entry, {total_debit, total_credit} ->
      {entry_debit, entry_credit} =
        entry.lines
        |> Enum.reduce({Decimal.new(0), Decimal.new(0)}, fn line, {d, c} ->
          {Decimal.add(d, line.debit || Decimal.new(0)),
           Decimal.add(c, line.credit || Decimal.new(0))}
        end)

      {Decimal.add(total_debit, entry_debit), Decimal.add(total_credit, entry_credit)}
    end)
  end

  defp get_journal_entries(tenant_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    query =
      from(
        je in CyberCore.Accounting.JournalEntry,
        join: l in assoc(je, :lines),
        join: a in assoc(l, :account),
        where:
          je.tenant_id == ^tenant_id and
            je.document_date >= ^start_date and
            je.document_date <= ^end_date and
            je.is_posted == true,
        order_by: [asc: je.document_date, asc: je.id, asc: l.line_order],
        select: {je, l, a}
      )

    Repo.all(query)
    |> Enum.group_by(
      fn {entry, _line, _account} -> entry.id end,
      fn {entry, line, account} -> {entry, line, account} end
    )
    |> Enum.map(fn {_entry_id, transactions} ->
      entry_struct = elem(hd(transactions), 0)
      lines =
        Enum.map(transactions, fn {_entry, line, account} ->
          line
          |> Map.put(:account_code, account.code)
          |> Map.put(:debit, line.debit_amount)
          |> Map.put(:credit, line.credit_amount)
        end)
      Map.put(entry_struct, :lines, lines)
      |> Map.put(:date, entry_struct.document_date)
    end)
  end

  # Helper functions

  defp get_month(%Date{} = date), do: date.month
  defp get_month(_), do: Date.utc_today().month

  defp get_year(%Date{} = date), do: date.year
  defp get_year(_), do: Date.utc_today().year

  defp format_date(nil), do: Date.utc_today() |> Date.to_iso8601()
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt) |> Date.to_iso8601()
  defp format_date(date), do: to_string(date)

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_decimal(n) when is_number(n), do: :erlang.float_to_binary(n / 1, decimals: 2)
  defp format_decimal(s), do: to_string(s)

  defp escape_xml(nil), do: ""

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape_xml(text), do: escape_xml(to_string(text))
end
