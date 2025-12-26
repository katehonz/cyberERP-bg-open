defmodule CyberCore.Inventory.ProductUnit do
  @moduledoc """
  Връзка между продукт и мерна единица с коефициент за конверсия.
  Позволява мулти мерни единици за един продукт.

  Пример:
  - Продукт: Мляко
    - Основна единица: литър (коефициент: 1.0)
    - Допълнителна: кутия 12x1л (коефициент: 12.0)
    - Допълнителна: палет 60 кутии (коефициент: 720.0)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.{Product, MeasurementUnit}
  alias Decimal

  @fields ~w(product_id measurement_unit_id conversion_factor is_primary is_active barcode)a

  schema "product_units" do
    belongs_to :product, Product
    belongs_to :measurement_unit, MeasurementUnit

    field :conversion_factor, :decimal
    field :is_primary, :boolean, default: false
    field :is_active, :boolean, default: true
    field :barcode, :string

    timestamps()
  end

  def changeset(product_unit, attrs) do
    product_unit
    |> cast(attrs, @fields)
    |> validate_required([:product_id, :measurement_unit_id, :conversion_factor])
    |> validate_decimal(:conversion_factor)
    |> validate_conversion_factor()
    |> unique_constraint([:product_id, :measurement_unit_id],
      name: :product_units_product_id_measurement_unit_id_index
    )
    |> unique_constraint(:barcode, name: :product_units_barcode_index)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:measurement_unit_id)
  end

  defp validate_decimal(changeset, field) do
    changeset
    |> validate_change(field, fn ^field, value ->
      cond do
        is_nil(value) ->
          []

        Decimal.compare(value, Decimal.new(0)) == :gt ->
          []

        true ->
          [{field, "трябва да е по-голямо от 0"}]
      end
    end)
  end

  defp validate_conversion_factor(changeset) do
    conversion_factor = get_field(changeset, :conversion_factor)
    is_primary = get_field(changeset, :is_primary)

    cond do
      is_primary && conversion_factor && Decimal.compare(conversion_factor, Decimal.new(1)) != :eq ->
        add_error(changeset, :conversion_factor, "основната единица трябва да има коефициент 1.0")

      true ->
        changeset
    end
  end

  @doc """
  Конвертира количество от една мерна единица в друга за даден продукт
  """
  def convert(from_unit, to_unit, quantity) do
    # from_factor = 12.0 (кутия)
    # to_factor = 1.0 (литър)
    # quantity = 5 кутии
    # result = 5 * 12.0 / 1.0 = 60 литра

    quantity
    |> Decimal.mult(from_unit.conversion_factor)
    |> Decimal.div(to_unit.conversion_factor)
  end
end
