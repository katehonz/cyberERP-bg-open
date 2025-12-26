defmodule CyberCore.Bank.Parsers.CAMT053Wise do
  @moduledoc """
  Парсер за CAMT.053 XML файлове от Wise.

  CAMT.053 е ISO 20022 стандарт за банкови извлечения.
  Wise използва този формат за експорт на транзакции.
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  import SweetXml

  @impl true
  def parse_file(file_path) do
    content = File.read!(file_path)
    parse_xml(content)
  end

  defp parse_xml(xml_content) do
    # Define namespaces
    namespaces = [
      camt: "urn:iso:std:iso:20022:tech:xsd:camt.053.001.02"
    ]

    # Extract statement data
    statement =
      xml_content
      |> xpath(~x"//camt:Stmt"e,
        opening_balance:
          ~x"./camt:Bal[camt:Tp/camt:CdOrPrtry/camt:Cd/text()='OPBD']/camt:Amt/text()"s
          |> transform_by(&parse_amount/1),
        closing_balance:
          ~x"./camt:Bal[camt:Tp/camt:CdOrPrtry/camt:Cd/text()='CLBD']/camt:Amt/text()"s
          |> transform_by(&parse_amount/1),
        from_date: ~x"./camt:FrToDt/camt:FrDtTm/text()"s |> transform_by(&parse_datetime/1),
        to_date: ~x"./camt:FrToDt/camt:ToDtTm/text()"s |> transform_by(&parse_datetime/1),
        transactions: [
          ~x"./camt:Ntry"l,
          booking_date: ~x"./camt:BookgDt/camt:Dt/text()"s |> transform_by(&parse_date_iso/1),
          value_date: ~x"./camt:ValDt/camt:Dt/text()"s |> transform_by(&parse_date_iso/1),
          amount: ~x"./camt:Amt/text()"s |> transform_by(&parse_amount/1),
          currency: ~x"./camt:Amt/@Ccy"s,
          credit_debit: ~x"./camt:CdtDbtInd/text()"s,
          description: ~x"./camt:NtryDtls/camt:TxDtls/camt:RmtInf/camt:Ustrd/text()"s,
          reference: ~x"./camt:NtryDtls/camt:TxDtls/camt:Refs/camt:EndToEndId/text()"s,
          counterpart_name:
            ~x"./camt:NtryDtls/camt:TxDtls/camt:RltdPties/camt:Dbtr/camt:Nm/text()"s,
          counterpart_iban:
            ~x"./camt:NtryDtls/camt:TxDtls/camt:RltdPties/camt:DbtrAcct/camt:Id/camt:IBAN/text()"s
        ]
      )

    transactions =
      statement.transactions
      |> Enum.map(fn tx ->
        %{
          booking_date: tx.booking_date || Date.utc_today(),
          value_date: tx.value_date,
          amount: tx.amount || Decimal.new(0),
          currency: tx.currency || "EUR",
          is_credit: tx.credit_debit == "CRDT",
          description: tx.description || "",
          reference: tx.reference,
          counterpart_name: tx.counterpart_name,
          counterpart_iban: tx.counterpart_iban,
          counterpart_bic: nil
        }
      end)

    if Enum.empty?(transactions) do
      {:error, "No transactions found"}
    else
      {:ok,
       %{
         period_from: statement.from_date || Date.utc_today(),
         period_to: statement.to_date || Date.utc_today(),
         opening_balance: statement.opening_balance,
         closing_balance: statement.closing_balance,
         transactions: transactions
       }}
    end
  rescue
    error ->
      {:error, "Failed to parse CAMT053: #{Exception.message(error)}"}
  end

  defp parse_amount(""), do: Decimal.new(0)
  defp parse_amount(nil), do: Decimal.new(0)

  defp parse_amount(amount_string) when is_binary(amount_string) do
    case Decimal.parse(String.trim(amount_string)) do
      {decimal, _} -> Decimal.abs(decimal)
      :error -> Decimal.new(0)
    end
  end

  defp parse_date_iso(""), do: Date.utc_today()
  defp parse_date_iso(nil), do: Date.utc_today()

  defp parse_date_iso(date_string) when is_binary(date_string) do
    case Date.from_iso8601(String.trim(date_string)) do
      {:ok, date} -> date
      {:error, _} -> Date.utc_today()
    end
  end

  defp parse_datetime(""), do: Date.utc_today()
  defp parse_datetime(nil), do: Date.utc_today()

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(String.trim(datetime_string)) do
      {:ok, datetime, _} -> DateTime.to_date(datetime)
      {:error, _} -> Date.utc_today()
    end
  end
end
