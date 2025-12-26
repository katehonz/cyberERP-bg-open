defmodule CyberCore.SAFT.Nomenclature.AssetMovementType do
  @moduledoc """
  Номенклатура за движение на активи (Asset Movement Types) според SAF-T България.

  Кодовете се използват за попълване на полето AssetTransactionType.

  ## Кодове:
  - 10: ACQ - Придобиване
  - 20: IMP - Подобрение/Увеличаване
  - 30: DEP - Амортизация
  - 40: REV - Преоценка
  - 50: DSP - Продажба
  - 60: SCR - Брак/Отписване
  - 70: TRF - Вътрешен трансфер
  - 80: COR - Корекция
  """

  @types %{
    "10" => %{code: "10", short: "ACQ", name_bg: "Придобиване", name_en: "Acquisition"},
    "20" => %{code: "20", short: "IMP", name_bg: "Подобрение/Увеличаване", name_en: "Improvement"},
    "30" => %{code: "30", short: "DEP", name_bg: "Амортизация", name_en: "Depreciation"},
    "40" => %{code: "40", short: "REV", name_bg: "Преоценка", name_en: "Revaluation"},
    "50" => %{code: "50", short: "DSP", name_bg: "Продажба", name_en: "Disposal/Sale"},
    "60" => %{code: "60", short: "SCR", name_bg: "Брак/Отписване", name_en: "Scrap/Write-off"},
    "70" => %{code: "70", short: "TRF", name_bg: "Вътрешен трансфер", name_en: "Internal transfer"},
    "80" => %{code: "80", short: "COR", name_bg: "Корекция", name_en: "Correction"}
  }

  @valid_codes Map.keys(@types)

  @doc """
  Връща всички валидни кодове.
  """
  def all_codes, do: @valid_codes

  @doc """
  Връща всички типове движения.
  """
  def all, do: Map.values(@types)

  @doc """
  Връща информация за конкретен код.
  """
  def get(code) when is_binary(code), do: Map.get(@types, code)
  def get(code) when is_integer(code), do: get(to_string(code))

  @doc """
  Проверява дали кодът е валиден.
  """
  def valid?(code) when is_binary(code), do: code in @valid_codes
  def valid?(code) when is_integer(code), do: valid?(to_string(code))
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
  Връща кратко име за даден код.
  """
  def short_name(code) do
    case get(code) do
      nil -> nil
      type -> type.short
    end
  end

  @doc """
  Връща пълно описание: код + кратко име + български текст.
  """
  def full_description(code) do
    case get(code) do
      nil -> nil
      type -> "#{type.code}: #{type.short} - #{type.name_bg}"
    end
  end

  @doc """
  Мапира вътрешен тип транзакция към SAF-T код.
  """
  def from_internal_type(type) do
    mapping = %{
      "acquisition" => "10",
      "purchase" => "10",
      "improvement" => "20",
      "increase" => "20",
      "depreciation" => "30",
      "revaluation" => "40",
      "sale" => "50",
      "disposal" => "50",
      "scrap" => "60",
      "write_off" => "60",
      "transfer" => "70",
      "correction" => "80"
    }

    Map.get(mapping, type, "80")
  end
end
