defmodule CyberCore.Manufacturing.ProductionOrderMaterial do
  @moduledoc """
  Материал в производствена поръчка - проследяване на материали за производство.

  Проследява:
  - Планирани vs реално изразходвани количества
  - Статус на издаване
  - Разходи
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Manufacturing.{ProductionOrder, TechCardMaterial}
  alias CyberCore.Inventory.Product

  @statuses ~w(pending issued partial_issued returned)

  schema "production_order_materials" do
    field :tenant_id, :integer
    belongs_to :production_order, ProductionOrder
    belongs_to :tech_card_material, TechCardMaterial
    belongs_to :product, Product

    field :line_no, :integer, default: 10
    field :description, :string

    # Количества
    field :planned_quantity, :decimal
    field :actual_quantity, :decimal
    field :unit, :string, default: "бр."

    # Цена
    field :unit_cost, :decimal, default: Decimal.new(0)
    field :total_cost, :decimal, default: Decimal.new(0)

    # Статус
    field :status, :string, default: "pending"

    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(material, attrs) do
    material
    |> cast(attrs, [
      :tenant_id,
      :production_order_id,
      :tech_card_material_id,
      :product_id,
      :line_no,
      :description,
      :planned_quantity,
      :actual_quantity,
      :unit,
      :unit_cost,
      :total_cost,
      :status,
      :notes
    ])
    |> validate_required([:tenant_id, :production_order_id, :product_id, :planned_quantity])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:planned_quantity, greater_than: 0)
    |> validate_number(:unit_cost, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:production_order_id)
    |> foreign_key_constraint(:tech_card_material_id)
    |> foreign_key_constraint(:product_id)
  end

  @doc """
  Издава материала към производството.
  """
  def issue_changeset(material, quantity) do
    material
    |> change(%{
      actual_quantity: quantity,
      status: "issued"
    })
    |> calculate_cost()
  end

  @doc """
  Частично издаване на материал.
  """
  def partial_issue_changeset(material, quantity) do
    current = material.actual_quantity || Decimal.new(0)
    new_qty = Decimal.add(current, quantity)
    new_status = if Decimal.gte?(new_qty, material.planned_quantity), do: "issued", else: "partial_issued"

    material
    |> change(%{actual_quantity: new_qty, status: new_status})
    |> calculate_cost()
  end

  @doc """
  Връща материал обратно в склада.
  """
  def return_changeset(material, quantity, reason \\ nil) do
    current = material.actual_quantity || Decimal.new(0)
    new_qty = Decimal.sub(current, quantity)

    status = cond do
      Decimal.lte?(new_qty, Decimal.new(0)) -> "pending"
      Decimal.lt?(new_qty, material.planned_quantity) -> "partial_issued"
      true -> "issued"
    end

    material
    |> change(%{
      actual_quantity: Decimal.max(new_qty, Decimal.new(0)),
      status: status,
      notes: reason
    })
    |> calculate_cost()
  end

  defp calculate_cost(changeset) do
    qty = get_field(changeset, :actual_quantity) || get_field(changeset, :planned_quantity)
    unit_cost = get_field(changeset, :unit_cost)

    if qty && unit_cost do
      total = Decimal.mult(qty, unit_cost)
      put_change(changeset, :total_cost, total)
    else
      changeset
    end
  end

  @doc """
  Изчислява разликата между планирано и реално количество.
  """
  def variance(%__MODULE__{planned_quantity: planned, actual_quantity: nil}), do: planned
  def variance(%__MODULE__{planned_quantity: planned, actual_quantity: actual}) do
    Decimal.sub(actual, planned)
  end

  @doc """
  Процент на изпълнение.
  """
  def fulfillment_percent(%__MODULE__{actual_quantity: nil}), do: Decimal.new(0)
  def fulfillment_percent(%__MODULE__{planned_quantity: planned, actual_quantity: actual}) do
    if Decimal.gt?(planned, Decimal.new(0)) do
      Decimal.div(actual, planned) |> Decimal.mult(Decimal.new(100)) |> Decimal.round(2)
    else
      Decimal.new(100)
    end
  end

  @doc """
  Списък със статуси.
  """
  def statuses, do: @statuses

  def status_label("pending"), do: "Чакащ"
  def status_label("issued"), do: "Издаден"
  def status_label("partial_issued"), do: "Частично издаден"
  def status_label("returned"), do: "Върнат"
  def status_label(_), do: "Неизвестен"
end
