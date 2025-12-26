defmodule CyberCore.Vat.Deklar do
  @moduledoc """
  This module provides functions for generating the DEKLAR.TXT file.
  """

  def generate_deklar_txt(tenant_id, year, month, prodagbi_content, pokupki_content) do
    prodagbi_data = CyberCore.Vat.Parser.parse_prodagbi(prodagbi_content)
    pokupki_data = CyberCore.Vat.Parser.parse_pokupki(pokupki_content)

    kletka_01_01 = sum_prodagbi(prodagbi_data, "02-10")
    kletka_01_11 = sum_prodagbi(prodagbi_data, "02-11")
    kletka_01_12 = sum_prodagbi(prodagbi_data, "02-12")
    kletka_01_13 = sum_prodagbi(prodagbi_data, "02-13")
    kletka_01_14 = sum_prodagbi(prodagbi_data, "02-14")
    kletka_01_15 = sum_prodagbi(prodagbi_data, "02-15")
    kletka_01_16 = sum_prodagbi(prodagbi_data, "02-16")
    kletka_01_17 = sum_prodagbi(prodagbi_data, "02-17")
    kletka_01_18 = sum_prodagbi(prodagbi_data, "02-18")
    kletka_01_19 = sum_prodagbi(prodagbi_data, "02-19")
    kletka_01_20 = sum_prodagbi(prodagbi_data, "02-20")
    kletka_01_21 = sum_prodagbi(prodagbi_data, "02-21")
    kletka_01_22 = sum_prodagbi(prodagbi_data, "02-22")
    kletka_01_23 = sum_prodagbi(prodagbi_data, "02-23")
    kletka_01_24 = sum_prodagbi(prodagbi_data, "02-24")

    kletka_01_30 = sum_pokupki(pokupki_data, "03-10")
    kletka_01_31 = sum_pokupki(pokupki_data, "03-11")
    kletka_01_32 = sum_pokupki(pokupki_data, "03-12")
    kletka_01_41 = sum_pokupki(pokupki_data, "03-13")
    kletka_01_42 = sum_pokupki(pokupki_data, "03-14")
    kletka_01_43 = sum_pokupki(pokupki_data, "03-15")

    [
      format_field(tenant_id, 15),
      format_field("Демо ЕООД", 50),
      format_field(format_period(year, month), 6),
      format_field("Лице, подаващо данните", 50),
      format_field(length(prodagbi_data), 15, :numeric),
      format_field(length(pokupki_data), 15, :numeric),
      format_field(kletka_01_01, 15, :numeric),
      format_field(kletka_01_20, 15, :numeric),
      format_field(kletka_01_11, 15, :numeric),
      format_field(kletka_01_21, 15, :numeric),
      format_field(kletka_01_12, 15, :numeric),
      format_field(kletka_01_22, 15, :numeric),
      format_field(kletka_01_23, 15, :numeric),
      format_field(kletka_01_13, 15, :numeric),
      format_field(kletka_01_24, 15, :numeric),
      format_field(kletka_01_14, 15, :numeric),
      format_field(kletka_01_15, 15, :numeric),
      format_field(kletka_01_16, 15, :numeric),
      format_field(kletka_01_17, 15, :numeric),
      format_field(kletka_01_18, 15, :numeric),
      format_field(kletka_01_19, 15, :numeric),
      format_field(kletka_01_30, 15, :numeric),
      format_field(kletka_01_31, 15, :numeric),
      format_field(kletka_01_41, 15, :numeric),
      format_field(kletka_01_32, 15, :numeric),
      format_field(kletka_01_42, 15, :numeric),
      format_field(kletka_01_43, 15, :numeric)
    ]
    |> Enum.join("")
  end

  defp sum_prodagbi(prodagbi_data, key) do
    prodagbi_data
    |> Enum.map(&Map.get(&1, key, Decimal.new(0)))
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp sum_pokupki(pokupki_data, key) do
    pokupki_data
    |> Enum.map(&Map.get(&1, key, Decimal.new(0)))
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
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

  defp format_period(year, month) do
    "#{year}#{String.pad_leading(to_string(month), 2, "0")}"
  end
end
