defmodule CyberCore.Inventory.StockLevel do
  @moduledoc """
  Складови наличности по продукт и склад.
  Този модул е материализиран view или се изчислява динамично.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "stock_levels" do
    field :tenant_id, :integer

    # Връзки
    belongs_to :product, CyberCore.Inventory.Product
    belongs_to :warehouse, CyberCore.Inventory.Warehouse

    # Количества
    field :quantity_on_hand, :decimal, default: Decimal.new(0)
    field :quantity_reserved, :decimal, default: Decimal.new(0)
    field :quantity_available, :decimal, default: Decimal.new(0)
    field :minimum_quantity, :decimal, default: Decimal.new(0)
    field :reorder_point, :decimal, default: Decimal.new(0)

    # Стойности
    field :average_cost, :decimal
    field :last_cost, :decimal
    field :total_value, :decimal

    timestamps()
  end

  @doc false
  def changeset(stock_level, attrs) do
    stock_level
    |> cast(attrs, [
      :tenant_id,
      :product_id,
      :warehouse_id,
      :quantity_on_hand,
      :quantity_reserved,
      :quantity_available,
      :minimum_quantity,
      :reorder_point,
      :average_cost,
      :last_cost,
      :total_value
    ])
    |> validate_required([:tenant_id, :product_id, :warehouse_id])
    |> unique_constraint([:tenant_id, :product_id, :warehouse_id])
    |> calculate_available_quantity()
    |> calculate_total_value()
  end

  defp calculate_available_quantity(changeset) do
    on_hand = get_field(changeset, :quantity_on_hand) || Decimal.new(0)
    reserved = get_field(changeset, :quantity_reserved) || Decimal.new(0)

    available = Decimal.sub(on_hand, reserved)
    put_change(changeset, :quantity_available, available)
  end

  defp calculate_total_value(changeset) do
    quantity = get_field(changeset, :quantity_on_hand)
    avg_cost = get_field(changeset, :average_cost)

    if quantity && avg_cost do
      total = Decimal.mult(quantity, avg_cost)
      put_change(changeset, :total_value, total)
    else
      changeset
    end
  end
end
