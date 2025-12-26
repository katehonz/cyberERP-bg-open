defmodule CyberCore.Inventory.StockCostLayer do
  @moduledoc """
  Слой за FIFO/LIFO оценка на материалните запаси.

  Всяко приемане на стока създава нов слой с количество и цена.
  При изписване се консумират слоевете според метода:
  - FIFO: първо се изписват най-старите слоеве
  - LIFO: първо се изписват най-новите слоеве
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Inventory.{Product, Warehouse, StockMovement}

  @statuses ~w(active depleted)

  schema "stock_cost_layers" do
    belongs_to :tenant, Tenant
    belongs_to :product, Product
    belongs_to :warehouse, Warehouse
    belongs_to :stock_movement, StockMovement

    field :layer_date, :date
    field :original_quantity, :decimal
    field :remaining_quantity, :decimal
    field :unit_cost, :decimal
    field :status, :string, default: "active"

    timestamps()
  end

  @doc false
  def changeset(layer, attrs) do
    layer
    |> cast(attrs, [
      :tenant_id,
      :product_id,
      :warehouse_id,
      :stock_movement_id,
      :layer_date,
      :original_quantity,
      :remaining_quantity,
      :unit_cost,
      :status
    ])
    |> validate_required([
      :tenant_id,
      :product_id,
      :warehouse_id,
      :layer_date,
      :original_quantity,
      :remaining_quantity,
      :unit_cost
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:original_quantity, greater_than: 0)
    |> validate_number(:remaining_quantity, greater_than_or_equal_to: 0)
    |> validate_number(:unit_cost, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:warehouse_id)
  end

  @doc """
  Създава нов слой от движение за приемане.
  """
  def from_movement(%StockMovement{} = movement) do
    %__MODULE__{
      tenant_id: movement.tenant_id,
      product_id: movement.product_id,
      warehouse_id: movement.warehouse_id,
      stock_movement_id: movement.id,
      layer_date: movement.movement_date,
      original_quantity: movement.quantity,
      remaining_quantity: movement.quantity,
      unit_cost: movement.unit_cost || Decimal.new(0),
      status: "active"
    }
  end

  @doc """
  Проверява дали слоят е изчерпан.
  """
  def depleted?(%__MODULE__{remaining_quantity: qty}) do
    Decimal.eq?(qty, Decimal.new(0))
  end

  @doc """
  Изчислява стойността на оставащото количество.
  """
  def remaining_value(%__MODULE__{remaining_quantity: qty, unit_cost: cost}) do
    Decimal.mult(qty, cost)
  end
end
