defmodule CyberCore.Manufacturing.TechCard do
  @moduledoc """
  Технологична карта - замества рецептите с по-богата структура.

  Включва:
  - Материали (BOM) с коефициенти и формули
  - Операции с работни центрове и времена
  - Автоматично изчисляване на разходи
  - Версиониране и валидност
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product
  alias CyberCore.Manufacturing.{TechCardMaterial, TechCardOperation}

  schema "tech_cards" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :description, :string

    # Изходен продукт
    belongs_to :output_product, Product
    field :output_quantity, :decimal, default: Decimal.new(1)
    field :output_unit, :string, default: "бр."

    # Версия и валидност
    field :version, :string, default: "1.0"
    field :valid_from, :date
    field :valid_to, :date
    field :is_active, :boolean, default: true

    # Разходи (изчислени автоматично)
    field :material_cost, :decimal, default: Decimal.new(0)
    field :labor_cost, :decimal, default: Decimal.new(0)
    field :machine_cost, :decimal, default: Decimal.new(0)
    field :overhead_cost, :decimal, default: Decimal.new(0)
    field :total_cost, :decimal, default: Decimal.new(0)

    # Overhead коефициент
    field :overhead_percent, :decimal, default: Decimal.new(0)

    field :notes, :string

    # Релации
    has_many :materials, TechCardMaterial
    has_many :operations, TechCardOperation

    timestamps()
  end

  @doc false
  def changeset(tech_card, attrs) do
    tech_card
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :description,
      :output_product_id,
      :output_quantity,
      :output_unit,
      :version,
      :valid_from,
      :valid_to,
      :is_active,
      :material_cost,
      :labor_cost,
      :machine_cost,
      :overhead_cost,
      :total_cost,
      :overhead_percent,
      :notes
    ])
    |> validate_required([:tenant_id, :code, :name, :output_quantity])
    |> validate_number(:output_quantity, greater_than: 0)
    |> validate_number(:overhead_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_length(:code, max: 30)
    |> validate_length(:name, max: 120)
    |> validate_length(:version, max: 20)
    |> validate_date_range()
    |> unique_constraint(:code, name: :tech_cards_tenant_id_code_index)
    |> foreign_key_constraint(:output_product_id)
    |> foreign_key_constraint(:tenant_id)
  end

  defp validate_date_range(changeset) do
    valid_from = get_field(changeset, :valid_from)
    valid_to = get_field(changeset, :valid_to)

    if valid_from && valid_to && Date.compare(valid_from, valid_to) == :gt do
      add_error(changeset, :valid_to, "трябва да е след началната дата")
    else
      changeset
    end
  end

  @doc """
  Преизчислява общите разходи на технологичната карта.
  """
  def recalculate_costs(tech_card) do
    direct_costs = Decimal.add(tech_card.material_cost, tech_card.labor_cost)
    |> Decimal.add(tech_card.machine_cost)

    overhead = Decimal.mult(direct_costs, Decimal.div(tech_card.overhead_percent, Decimal.new(100)))
    total = Decimal.add(direct_costs, overhead)

    %{tech_card | overhead_cost: overhead, total_cost: total}
  end

  @doc """
  Проверява дали технологичната карта е валидна за дадена дата.
  """
  def valid_for_date?(%__MODULE__{valid_from: nil, valid_to: nil}, _date), do: true
  def valid_for_date?(%__MODULE__{valid_from: from, valid_to: nil}, date), do: Date.compare(date, from) != :lt
  def valid_for_date?(%__MODULE__{valid_from: nil, valid_to: to}, date), do: Date.compare(date, to) != :gt
  def valid_for_date?(%__MODULE__{valid_from: from, valid_to: to}, date) do
    Date.compare(date, from) != :lt && Date.compare(date, to) != :gt
  end

  @doc """
  Изчислява цена на единица изходен продукт.
  """
  def unit_cost(%__MODULE__{total_cost: total, output_quantity: qty}) do
    if Decimal.gt?(qty, Decimal.new(0)) do
      Decimal.div(total, qty)
    else
      Decimal.new(0)
    end
  end
end
