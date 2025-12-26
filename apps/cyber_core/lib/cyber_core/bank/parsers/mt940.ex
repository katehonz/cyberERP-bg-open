defmodule CyberCore.Bank.Parsers.MT940 do
  @moduledoc """
  Парсер за MT940 SWIFT формат.

  MT940 е стандартен SWIFT формат за банкови извлечения.
  Формат описан в: SWIFT MT940 Customer Statement Message

  Основни полета:
  - :20: Transaction Reference
  - :25: Account Identification
  - :28C: Statement Number
  - :60F: Opening Balance
  - :61: Statement Line
  - :62F: Closing Balance
  - :86: Additional Information
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  @impl true
  def parse_file(file_path) do
    content = File.read!(file_path)
    parse_content(content)
  end

  defp parse_content(content) do
    # Split по blocks (each transaction starts with :61:)
    lines = String.split(content, "\n")

    state = %{
      opening_balance: nil,
      closing_balance: nil,
      period_from: nil,
      period_to: nil,
      transactions: [],
      current_transaction: nil,
      current_description: []
    }

    result = parse_lines(lines, state)

    # Add last transaction if exists
    result =
      if result.current_transaction do
        add_transaction(result)
      else
        result
      end

    if Enum.empty?(result.transactions) do
      {:error, "No transactions found"}
    else
      {:ok,
       %{
         period_from: result.period_from,
         period_to: result.period_to,
         opening_balance: result.opening_balance,
         closing_balance: result.closing_balance,
         transactions: Enum.reverse(result.transactions)
       }}
    end
  rescue
    error ->
      {:error, "Failed to parse MT940: #{Exception.message(error)}"}
  end

  defp parse_lines([], state), do: state

  defp parse_lines([line | rest], state) do
    line = String.trim(line)

    cond do
      # Opening Balance: :60F:C230115EUR1234,56
      String.starts_with?(line, ":60F:") ->
        balance = parse_balance_line(line)
        parse_lines(rest, %{state | opening_balance: balance.amount, period_from: balance.date})

      # Closing Balance: :62F:C230131EUR2345,67
      String.starts_with?(line, ":62F:") ->
        balance = parse_balance_line(line)
        parse_lines(rest, %{state | closing_balance: balance.amount, period_to: balance.date})

      # Statement Line (Transaction): :61:2301150115DR100,00NTRFNONREF//PAYMENT
      String.starts_with?(line, ":61:") ->
        # Save previous transaction
        state = if state.current_transaction, do: add_transaction(state), else: state
        transaction = parse_statement_line(line)
        parse_lines(rest, %{state | current_transaction: transaction, current_description: []})

      # Additional Info: :86:Payment for invoice 123
      String.starts_with?(line, ":86:") ->
        description = String.replace_prefix(line, ":86:", "")

        parse_lines(rest, %{
          state
          | current_description: [description | state.current_description]
        })

      # Continuation of previous field
      state.current_transaction != nil and line != "" ->
        parse_lines(rest, %{
          state
          | current_description: [line | state.current_description]
        })

      true ->
        parse_lines(rest, state)
    end
  end

  defp parse_balance_line(line) do
    # Format: :60F:C230115EUR1234,56
    # C/D (Credit/Debit), Date (YYMMDD), Currency (3 chars), Amount
    line = String.replace_prefix(line, ":60F:", "") |> String.replace_prefix(":62F:", "")

    <<cd::binary-size(1), date_str::binary-size(6), currency::binary-size(3), amount_str::binary>> =
      line

    date = parse_date_yymmdd(date_str)
    amount = parse_amount(amount_str)

    amount =
      if cd == "D" do
        Decimal.negate(amount)
      else
        amount
      end

    %{date: date, currency: currency, amount: amount}
  end

  defp parse_statement_line(line) do
    # Format: :61:2301150115DR100,00NTRFNONREF
    # Value Date (YYMMDD), Booking Date (MMDD), C/D, Amount, Transaction Type, Reference
    line = String.replace_prefix(line, ":61:", "")

    <<value_date_str::binary-size(6), booking_date_str::binary-size(4), cd::binary-size(1),
      _cd2::binary-size(1), rest::binary>> = line

    # Parse amount (до следващия non-digit character)
    {amount_str, rest} = extract_amount(rest)

    value_date = parse_date_yymmdd(value_date_str)
    booking_date = parse_date_mmdd(booking_date_str, value_date.year)

    amount = parse_amount(amount_str)
    is_credit = cd == "C"

    %{
      booking_date: booking_date,
      value_date: value_date,
      amount: amount,
      currency: "EUR",
      # Will be updated from :86:
      is_credit: is_credit,
      description: "",
      reference: String.trim(rest),
      counterpart_name: nil,
      counterpart_iban: nil,
      counterpart_bic: nil
    }
  end

  defp add_transaction(state) do
    description = state.current_description |> Enum.reverse() |> Enum.join(" ")

    transaction = %{
      state.current_transaction
      | description: description
    }

    %{
      state
      | transactions: [transaction | state.transactions],
        current_transaction: nil,
        current_description: []
    }
  end

  defp extract_amount(string) do
    # Extract amount until we hit a letter
    amount =
      string
      |> String.graphemes()
      |> Enum.take_while(fn c ->
        c in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "."]
      end)
      |> Enum.join()

    rest = String.replace_prefix(string, amount, "")
    {amount, rest}
  end

  defp parse_date_yymmdd(<<yy::binary-size(2), mm::binary-size(2), dd::binary-size(2)>>) do
    year = String.to_integer(yy) + 2000
    month = String.to_integer(mm)
    day = String.to_integer(dd)
    Date.new!(year, month, day)
  end

  defp parse_date_mmdd(<<mm::binary-size(2), dd::binary-size(2)>>, year) do
    month = String.to_integer(mm)
    day = String.to_integer(dd)
    Date.new!(year, month, day)
  end

  defp parse_amount(amount_string) do
    amount_string
    |> String.replace(",", ".")
    |> String.trim()
    |> Decimal.new()
    |> Decimal.abs()
  end
end
