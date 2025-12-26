defmodule CyberCore.Bank.Parsers.Parser do
  @moduledoc """
  Behaviour за банкови файлови парсери.

  Всеки парсер трябва да имплементира `parse_file/1` и да върне
  структурирани данни за транзакциите.
  """

  @doc """
  Парсва файл и връща структурирани банкови данни.

  Връща:
    {:ok, %{
      period_from: Date.t(),
      period_to: Date.t(),
      opening_balance: Decimal.t(),
      closing_balance: Decimal.t(),
      transactions: [transaction()]
    }}

  Където transaction() е:
    %{
      booking_date: Date.t(),
      value_date: Date.t() | nil,
      amount: Decimal.t(),
      currency: String.t(),
      is_credit: boolean(),
      description: String.t(),
      reference: String.t() | nil,
      counterpart_name: String.t() | nil,
      counterpart_iban: String.t() | nil,
      counterpart_bic: String.t() | nil
    }
  """
  @callback parse_file(file_path :: String.t()) ::
              {:ok, map()} | {:error, String.t()}
end
