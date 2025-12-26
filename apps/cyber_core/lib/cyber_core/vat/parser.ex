defmodule CyberCore.Vat.Parser do
  @moduledoc """
  This module provides functions for parsing VAT declaration files.
  """

  def parse_prodagbi(content) do
    content
    |> String.split("\r\n", trim: true)
    |> Enum.map(&parse_prodagbi_line/1)
  end

  def parse_pokupki(content) do
    content
    |> String.split("\r\n", trim: true)
    |> Enum.map(&parse_pokupki_line/1)
  end

  @prodagbi_schema [
    {"02-00", 0, 15, :string},
    {"02-01", 15, 6, :string},
    {"02-02", 21, 4, :string},
    {"02-03", 25, 15, :string},
    {"02-04", 40, 2, :string},
    {"02-05", 42, 20, :string},
    {"02-06", 62, 10, :string},
    {"02-07", 72, 15, :string},
    {"02-08", 87, 50, :string},
    {"02-09", 137, 30, :string},
    {"02-10", 167, 15, :decimal},
    {"02-11", 182, 15, :decimal},
    {"02-12", 197, 15, :decimal},
    {"02-13", 212, 15, :decimal},
    {"02-14", 227, 15, :decimal},
    {"02-15", 242, 15, :decimal},
    {"02-16", 257, 15, :decimal},
    {"02-17", 272, 15, :decimal},
    {"02-18", 287, 15, :decimal},
    {"02-19", 302, 15, :decimal},
    {"02-20", 317, 15, :decimal},
    {"02-21", 332, 15, :decimal},
    {"02-22", 347, 15, :decimal},
    {"02-23", 362, 15, :decimal},
    {"02-24", 377, 15, :decimal},
    {"02-25", 392, 15, :decimal},
    {"02-26", 407, 2, :string}
  ]

  defp parse_prodagbi_line(line) do
    @prodagbi_schema
    |> Enum.reduce(%{}, fn {key, start, len, type}, acc ->
      value =
        case type do
          :decimal -> extract_decimal(line, start, len)
          :string -> extract_string(line, start, len)
        end

      Map.put(acc, key, value)
    end)
  end

  @pokupki_schema [
    {"03-00", 0, 15, :string},
    {"03-01", 15, 6, :string},
    {"03-02", 21, 4, :string},
    {"03-03", 25, 15, :string},
    {"03-04", 40, 2, :string},
    {"03-05", 42, 20, :string},
    {"03-06", 62, 10, :string},
    {"03-07", 72, 15, :string},
    {"03-08", 87, 50, :string},
    {"03-09", 137, 30, :string},
    {"03-10", 167, 15, :decimal},
    {"03-11", 182, 15, :decimal},
    {"03-12", 197, 15, :decimal},
    {"03-13", 212, 15, :decimal},
    {"03-14", 227, 15, :decimal},
    {"03-15", 242, 15, :decimal},
    {"03-16", 257, 15, :decimal},
    {"03-17", 272, 15, :decimal}
  ]

  defp parse_pokupki_line(line) do
    @pokupki_schema
    |> Enum.reduce(%{}, fn {key, start, len, type}, acc ->
      value =
        case type do
          :decimal -> extract_decimal(line, start, len)
          :string -> extract_string(line, start, len)
        end

      Map.put(acc, key, value)
    end)
  end

  defp extract_decimal(line, start, length) do
    string_value =
      line
      |> String.slice(start, length)
      |> String.trim()

    if string_value == "" do
      Decimal.new(0)
    else
      Decimal.new(string_value)
    end
  end

  defp extract_string(line, start, length) do
    line
    |> String.slice(start, length)
    |> String.trim()
  end
end
