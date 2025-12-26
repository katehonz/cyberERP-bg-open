defmodule CyberCore.Bank.Parsers.CAMT053Revolut do
  @moduledoc """
  Парсер за CAMT.053 XML файлове от Revolut.

  Базиран на CyberCore.Bank.Parsers.CAMT053Wise с малки адаптации за Revolut формата.
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  # За момента използваме същия парсер като Wise
  # Revolut също използва стандартен CAMT.053
  defdelegate parse_file(file_path), to: CyberCore.Bank.Parsers.CAMT053Wise
end
