defmodule CyberCore.Bank.Parsers.PostbankXML do
  @moduledoc """
  Парсер за XML файлове от Пощенска банка.

  Пощенска банка използва собствен XML формат.
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  import SweetXml

  @impl true
  def parse_file(file_path) do
    content = File.read!(file_path)
    parse_xml(content)
  end

  defp parse_xml(xml_content) do
    # Postbank използва custom XML формат
    # Този парсер е опростена версия и трябва да се адаптира
    # към действителния формат на Пощенска банка

    transactions =
      xml_content
      |> xpath(~x"//Transaction"l,
        date: ~x"./Date/text()"s,
        amount: ~x"./Amount/text()"s,
        type: ~x"./Type/text()"s,
        description: ~x"./Description/text()"s,
        counterpart: ~x"./Counterpart/text()"s,
        iban: ~x"./IBAN/text()"s
      )
      |> Enum.map(fn tx ->
        %{
          booking_date: parse_date(tx.date),
          value_date: parse_date(tx.date),
          amount: parse_amount(tx.amount),
          currency: "BGN",
          is_credit: tx.type == "Credit",
          description: tx.description || "",
          reference: nil,
          counterpart_name: tx.counterpart,
          counterpart_iban: tx.iban,
          counterpart_bic: nil
        }
      end)

    if Enum.empty?(transactions) do
      {:error, "No transactions found"}
    else
      dates = Enum.map(transactions, & &1.booking_date)

      {:ok,
       %{
         period_from: Enum.min(dates),
         period_to: Enum.max(dates),
         opening_balance: nil,
         closing_balance: nil,
         transactions: transactions
       }}
    end
  rescue
    error ->
      {:error, "Failed to parse Postbank XML: #{Exception.message(error)}"}
  end

  defp parse_date(""), do: Date.utc_today()
  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(date_string) when is_binary(date_string) do
    # Try DD.MM.YYYY format first (Bulgarian standard)
    cond do
      String.match?(date_string, ~r/^\d{2}\.\d{2}\.\d{4}$/) ->
        [day, month, year] = String.split(date_string, ".")
        Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

      # Then try ISO
      true ->
        case Date.from_iso8601(String.trim(date_string)) do
          {:ok, date} -> date
          {:error, _} -> Date.utc_today()
        end
    end
  end

  defp parse_amount(""), do: Decimal.new(0)
  defp parse_amount(nil), do: Decimal.new(0)

  defp parse_amount(amount_string) when is_binary(amount_string) do
    cleaned =
      amount_string
      |> String.replace(" ", "")
      |> String.replace(",", ".")
      |> String.trim()

    case Decimal.parse(cleaned) do
      {decimal, _} -> Decimal.abs(decimal)
      :error -> Decimal.new(0)
    end
  end
end
