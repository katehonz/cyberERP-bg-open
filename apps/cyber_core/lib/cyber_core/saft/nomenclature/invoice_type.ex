defmodule CyberCore.SAFT.Nomenclature.InvoiceType do
  @moduledoc """
  Видове фактури/документи според SAF-T България номенклатура.
  """

  @types %{
    "01" => %{code: "01", name_bg: "Фактура", name_en: "Invoice"},
    "02" => %{code: "02", name_bg: "Дебитно известие", name_en: "Debit note"},
    "03" => %{code: "03", name_bg: "Кредитно известие", name_en: "Credit note"},
    "04" => %{code: "04", name_bg: "Регистър на стоки под режим складиране (изпратени)", name_en: "Call-off stock register (dispatched)"},
    "05" => %{code: "05", name_bg: "Регистър на стоки под режим складиране (получени)", name_en: "Call-off stock register (received)"},
    "07" => %{code: "07", name_bg: "Митническа декларация", name_en: "Customs declaration"},
    "09" => %{code: "09", name_bg: "Протокол или друг документ", name_en: "Protocol or other document"},
    "11" => %{code: "11", name_bg: "Фактура - касова отчетност", name_en: "Invoice - cash accounting"},
    "12" => %{code: "12", name_bg: "Дебитно известие – касова отчетност", name_en: "Debit note - cash accounting"},
    "13" => %{code: "13", name_bg: "Кредитно известие – касова отчетност", name_en: "Credit note - cash accounting"},
    "23" => %{code: "23", name_bg: "Кредитно известие по чл. 126б, ал. 1 от ЗДДС", name_en: "Credit note under Art. 126b(1) VAT Act"},
    "29" => %{code: "29", name_bg: "Протокол по чл. 126б, ал. 2 и 7 от ЗДДС", name_en: "Protocol under Art. 126b(2)(7) VAT Act"},
    "81" => %{code: "81", name_bg: "Отчет за извършените продажби", name_en: "Sales report"},
    "82" => %{code: "82", name_bg: "Отчет за извършените продажби при специален ред на облагане", name_en: "Sales report - special taxation"},
    "91" => %{code: "91", name_bg: "Протокол за начисляване на данък по чл. 117 от ЗДДС", name_en: "Protocol Art. 117 VAT Act"},
    "92" => %{code: "92", name_bg: "Протокол по чл. 151в от ЗДДС", name_en: "Protocol Art. 151c VAT Act"},
    "93" => %{code: "93", name_bg: "Протокол за безвъзмездно предоставяне по чл. 6, ал. 3 от ЗДДС", name_en: "Protocol Art. 6(3) VAT Act"},
    "94" => %{code: "94", name_bg: "Протокол за лично ползване по чл. 27, ал. 6 от ЗДДС", name_en: "Protocol Art. 27(6) VAT Act"},
    "95" => %{code: "95", name_bg: "Протокол за корекция по чл. 79 от ЗДДС", name_en: "Protocol Art. 79 VAT Act"}
  }

  @valid_codes Map.keys(@types)

  @doc """
  Връща всички валидни кодове.
  """
  def all_codes, do: @valid_codes

  @doc """
  Връща всички типове фактури.
  """
  def all, do: @types |> Map.values() |> Enum.sort_by(& &1.code)

  @doc """
  Връща информация за конкретен код.
  """
  def get(code) when is_binary(code), do: Map.get(@types, code)

  @doc """
  Проверява дали кодът е валиден.
  """
  def valid_code?(code) when is_binary(code), do: code in @valid_codes
  def valid_code?(_), do: false

  @doc """
  Връща името на български за даден код.
  """
  def name_bg(code) do
    case get(code) do
      nil -> nil
      type -> type.name_bg
    end
  end
end
