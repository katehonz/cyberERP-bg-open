defmodule CyberCore.Bank.Parsers.CCBCSV do
  @moduledoc """
  Парсер за CSV файлове от ЦКБ (Централна Кооперативна Банка).

  Формат:
  - Дата;Вид плащане;Сметка;Контрагент;Основание;Дебит;Кредит;Валута
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  alias CSV

  @impl true
  def parse_file(file_path) do
    file_path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.to_list()
    |> parse_rows()
  end

  defp parse_rows([]) do
    {:error, "Empty CSV file"}
  end

  defp parse_rows(rows) do
    transactions =
      rows
      |> Enum.map(&parse_row/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(transactions) do
      {:error, "No valid transactions found"}
    else
      dates = Enum.map(transactions, & &1.booking_date)
      period_from = Enum.min(dates)
      period_to = Enum.max(dates)

      {:ok,
       %{
         period_from: period_from,
         period_to: period_to,
         opening_balance: nil,
         closing_balance: nil,
         transactions: transactions
       }}
    end
  end

  defp parse_row(row) do
    try do
      # Expected columns: Дата, Вид плащане, Сметка, Контрагент, Основание, Дебит, Кредит, Валута
      date = parse_date(row["Дата"] || row["Date"])
      debit = parse_amount(row["Дебит"] || row["Debit"])
      credit = parse_amount(row["Кредит"] || row["Credit"])

      {amount, is_credit} =
        cond do
          credit && Decimal.positive?(credit) -> {credit, true}
          debit && Decimal.positive?(debit) -> {debit, false}
          true -> {Decimal.new(0), false}
        end

      if Decimal.positive?(amount) do
        %{
          booking_date: date,
          value_date: date,
          amount: amount,
          currency: row["Валута"] || row["Currency"] || "BGN",
          is_credit: is_credit,
          description: row["Основание"] || row["Description"] || "",
          reference: row["Референция"] || row["Reference"],
          counterpart_name: row["Контрагент"] || row["Counterpart"],
          counterpart_iban: row["Сметка"] || row["Account"],
          counterpart_bic: nil
        }
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp parse_date(date_string) when is_binary(date_string) do
    # Try different date formats
    cond do
      # DD.MM.YYYY
      String.match?(date_string, ~r/^\d{2}\.\d{2}\.\d{4}$/) ->
        [day, month, year] = String.split(date_string, ".")
        Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

      # YYYY-MM-DD
      String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        Date.from_iso8601!(date_string)

      true ->
        Date.utc_today()
    end
  end

  defp parse_date(_), do: Date.utc_today()

  defp parse_amount(nil), do: Decimal.new(0)
  defp parse_amount(""), do: Decimal.new(0)

  defp parse_amount(amount_string) when is_binary(amount_string) do
    # Clean up amount: remove spaces, replace comma with dot
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

  defp parse_amount(amount) when is_number(amount), do: Decimal.new(to_string(amount))
  defp parse_amount(_), do: Decimal.new(0)
end
