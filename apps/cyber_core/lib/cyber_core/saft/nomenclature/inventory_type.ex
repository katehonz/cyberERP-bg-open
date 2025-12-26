defmodule CyberCore.SAFT.Nomenclature.InventoryType do
  @moduledoc """
  Номенклатура за вид на материалния запас (Inventory Types) според SAF-T България.

  Кодовете се използват за попълване на полето ProductType.

  ## Кодове:
  - 10: Материали
  - 20: Продукция
  - 30: Стоки
  - 40: Незавършено производство
  - 50: Инвестиция в материален запас
  """

  @types %{
    "10" => %{code: "10", name_bg: "Материали", name_en: "Materials"},
    "20" => %{code: "20", name_bg: "Продукция", name_en: "Finished goods"},
    "30" => %{code: "30", name_bg: "Стоки", name_en: "Goods for resale"},
    "40" => %{code: "40", name_bg: "Незавършено производство", name_en: "Work in progress"},
    "50" => %{code: "50", name_bg: "Инвестиция в материален запас", name_en: "Investment in inventory"}
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
  Връща името на английски за даден код.
  """
  def name_en(code) do
    case get(code) do
      nil -> nil
      type -> type.name_en
    end
  end

  @doc """
  Мапира вътрешен тип продукт към SAF-T код.
  """
  def from_product_type(type) do
    mapping = %{
      "material" => "10",
      "raw_material" => "10",
      "finished_good" => "20",
      "production" => "20",
      "product" => "20",
      "goods" => "30",
      "merchandise" => "30",
      "resale" => "30",
      "wip" => "40",
      "work_in_progress" => "40",
      "investment" => "50",
      "service" => "30"  # Услугите третираме като стоки
    }

    Map.get(mapping, type, "30")  # По подразбиране - стоки
  end
end
