defmodule CyberCore.Inventory.MeasurementUnit do
  @moduledoc """
  Мерни единици за продукти.
  Поддържа стандартизирани мерни единици съгласно SAF-T изискванията.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Inventory.ProductUnit

  @fields ~w(tenant_id code name_bg name_en symbol is_base is_active)a

  # Стандартни мерни единици според SAF-T
  @standard_units %{
    "kg" => %{name_bg: "Килограм", name_en: "Kilogram", symbol: "kg"},
    "g" => %{name_bg: "Грам", name_en: "Gram", symbol: "g"},
    "t" => %{name_bg: "Тон", name_en: "Ton", symbol: "t"},
    "l" => %{name_bg: "Литър", name_en: "Liter", symbol: "l"},
    "ml" => %{name_bg: "Мililитър", name_en: "Milliliter", symbol: "ml"},
    "m" => %{name_bg: "Метър", name_en: "Meter", symbol: "m"},
    "cm" => %{name_bg: "Сантиметър", name_en: "Centimeter", symbol: "cm"},
    "mm" => %{name_bg: "Милиметър", name_en: "Millimeter", symbol: "mm"},
    "m2" => %{name_bg: "Квадратен метър", name_en: "Square meter", symbol: "m²"},
    "m3" => %{name_bg: "Кубичен метър", name_en: "Cubic meter", symbol: "m³"},
    "p/st" => %{name_bg: "Брой", name_en: "Piece", symbol: "бр."},
    "pair" => %{name_bg: "Двойка", name_en: "Pair", symbol: "двойка"},
    "set" => %{name_bg: "Комплект", name_en: "Set", symbol: "компл."},
    "pack" => %{name_bg: "Пакет", name_en: "Package", symbol: "пак."},
    "box" => %{name_bg: "Кутия", name_en: "Box", symbol: "кут."},
    "pallet" => %{name_bg: "Палет", name_en: "Pallet", symbol: "палет"}
  }

  schema "measurement_units" do
    belongs_to :tenant, Tenant

    field :code, :string
    field :name_bg, :string
    field :name_en, :string
    field :symbol, :string
    field :is_base, :boolean, default: false
    field :is_active, :boolean, default: true

    has_many :product_units, ProductUnit

    timestamps()
  end

  def changeset(unit, attrs) do
    unit
    |> cast(attrs, @fields)
    |> validate_required([:tenant_id, :code, :name_bg, :symbol])
    |> validate_length(:code, max: 20)
    |> validate_length(:name_bg, max: 100)
    |> validate_length(:name_en, max: 100)
    |> validate_length(:symbol, max: 20)
    |> unique_constraint(:code, name: :measurement_units_tenant_id_code_index)
    |> foreign_key_constraint(:tenant_id)
  end

  def standard_units, do: @standard_units

  @doc """
  Връща списък с кодовете на стандартните мерни единици
  """
  def standard_unit_codes, do: Map.keys(@standard_units)
end
