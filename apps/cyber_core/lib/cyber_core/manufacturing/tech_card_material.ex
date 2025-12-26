defmodule CyberCore.Manufacturing.TechCardMaterial do
  @moduledoc """
  Материал в технологична карта (BOM ред).

  Поддържа:
  - Коефициент за изчисляване на количество
  - Процент на брак/загуби
  - Формула за изчисляване (Elixir expression)
  - Фиксирани vs пропорционални материали
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product
  alias CyberCore.Manufacturing.TechCard

  schema "tech_card_materials" do
    field :tenant_id, :integer
    belongs_to :tech_card, TechCard
    belongs_to :product, Product

    field :line_no, :integer, default: 10
    field :description, :string

    # Количество и мерна единица
    field :quantity, :decimal
    field :unit, :string, default: "бр."

    # Коефициенти
    field :coefficient, :decimal, default: Decimal.new("1.0")
    field :wastage_percent, :decimal, default: Decimal.new(0)

    # Формула за количество (опционална)
    # Променливи: quantity, coefficient, wastage_percent, output_quantity
    field :quantity_formula, :string

    # Цена
    field :unit_cost, :decimal, default: Decimal.new(0)
    field :total_cost, :decimal, default: Decimal.new(0)

    # Фиксиран материал (не зависи от количеството продукция)
    field :is_fixed, :boolean, default: false

    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(material, attrs) do
    material
    |> cast(attrs, [
      :tenant_id,
      :tech_card_id,
      :product_id,
      :line_no,
      :description,
      :quantity,
      :unit,
      :coefficient,
      :wastage_percent,
      :quantity_formula,
      :unit_cost,
      :total_cost,
      :is_fixed,
      :notes
    ])
    |> validate_required([:tenant_id, :tech_card_id, :product_id, :quantity])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:coefficient, greater_than: 0)
    |> validate_number(:wastage_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:unit_cost, greater_than_or_equal_to: 0)
    |> validate_formula(:quantity_formula)
    |> unique_constraint([:tech_card_id, :line_no], name: :tech_card_materials_tech_card_id_line_no_index)
    |> foreign_key_constraint(:tech_card_id)
    |> foreign_key_constraint(:product_id)
  end

  defp validate_formula(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      "" -> changeset
      formula ->
        case CyberCore.Manufacturing.FormulaEngine.validate_formula(formula) do
          :ok -> changeset
          {:error, reason} -> add_error(changeset, field, reason)
        end
    end
  end

  @doc """
  Изчислява ефективното количество материал за дадено количество продукция.

  ## Параметри
    - material: TechCardMaterial struct
    - output_quantity: количество продукция за производство

  ## Връща
    - Decimal: изчисленото количество материал
  """
  def calculate_quantity(%__MODULE__{} = material, output_quantity) do
    context = %{
      quantity: material.quantity,
      coefficient: material.coefficient,
      wastage_percent: material.wastage_percent,
      output_quantity: output_quantity,
      is_fixed: material.is_fixed
    }

    case material.quantity_formula do
      nil -> default_quantity_formula(context)
      "" -> default_quantity_formula(context)
      formula -> evaluate_formula(formula, context)
    end
  end

  defp default_quantity_formula(%{is_fixed: true, quantity: qty, coefficient: coef, wastage_percent: waste}) do
    # Фиксиран материал - не зависи от количеството продукция
    base = Decimal.mult(qty, coef)
    wastage_factor = Decimal.add(Decimal.new(1), Decimal.div(waste, Decimal.new(100)))
    Decimal.mult(base, wastage_factor)
  end

  defp default_quantity_formula(%{quantity: qty, coefficient: coef, wastage_percent: waste, output_quantity: output}) do
    # Пропорционален материал: quantity * coefficient * output_quantity * (1 + wastage/100)
    base = Decimal.mult(qty, coef) |> Decimal.mult(output)
    wastage_factor = Decimal.add(Decimal.new(1), Decimal.div(waste, Decimal.new(100)))
    Decimal.mult(base, wastage_factor)
  end

  defp evaluate_formula(formula, context) do
    CyberCore.Manufacturing.FormulaEngine.evaluate(formula, context)
  end

  @doc """
  Изчислява общата цена на материала.
  """
  def calculate_cost(%__MODULE__{} = material, output_quantity) do
    qty = calculate_quantity(material, output_quantity)
    Decimal.mult(qty, material.unit_cost)
  end
end
