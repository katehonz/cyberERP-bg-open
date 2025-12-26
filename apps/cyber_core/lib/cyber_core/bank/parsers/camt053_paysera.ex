defmodule CyberCore.Bank.Parsers.CAMT053Paysera do
  @moduledoc """
  Парсер за CAMT.053 XML файлове от Paysera.

  Базиран на CyberCore.Bank.Parsers.CAMT053Wise с малки адаптации за Paysera формата.
  """

  @behaviour CyberCore.Bank.Parsers.Parser

  # За момента използваме същия парсер като Wise
  # Paysera също използва стандартен CAMT.053
  defdelegate parse_file(file_path), to: CyberCore.Bank.Parsers.CAMT053Wise
end
