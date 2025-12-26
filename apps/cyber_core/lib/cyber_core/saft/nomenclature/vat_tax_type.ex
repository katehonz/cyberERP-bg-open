defmodule CyberCore.SAFT.Nomenclature.VatTaxType do
  @moduledoc """
  Номенклатура на данъчните режими по отношение на ДДС (VAT Tax Types) според SAF-T България.

  Кодовете се използват за попълване на полето TaxType в TaxIDStructure.

  ## Кодове:
  - 100010: Данъчно задължено лице, регистрирано за целите на ДДС
  - 100020: Всяко друго данъчно задължено лице
  - 100030: Данъчно незадължено лице
  """

  @types %{
    "100010" => %{
      code: "100010",
      name_bg: "Данъчно задължено лице, регистрирано за целите на ДДС",
      name_en: "VAT registered taxable person"
    },
    "100020" => %{
      code: "100020",
      name_bg: "Всяко друго данъчно задължено лице",
      name_en: "Other taxable person"
    },
    "100030" => %{
      code: "100030",
      name_bg: "Данъчно незадължено лице",
      name_en: "Non-taxable person"
    }
  }

  @valid_codes Map.keys(@types)

  @doc """
  Връща всички валидни кодове.
  """
  def all_codes, do: @valid_codes

  @doc """
  Връща всички типове.
  """
  def all, do: Map.values(@types)

  @doc """
  Връща информация за конкретен код.
  """
  def get(code) when is_binary(code), do: Map.get(@types, code)

  @doc """
  Проверява дали кодът е валиден.
  """
  def valid?(code) when is_binary(code), do: code in @valid_codes
  def valid?(_), do: false

  @doc """
  Връща името на български за даден код.
  """
  def name_bg(code) do
    case get(code) do
      nil -> nil
      type -> type.name_bg
    end
  end

  @doc """
  Определя кода на база ДДС регистрация.
  """
  def from_vat_status(is_vat_registered, is_taxable \\ true) do
    cond do
      is_vat_registered -> "100010"
      is_taxable -> "100020"
      true -> "100030"
    end
  end
end
