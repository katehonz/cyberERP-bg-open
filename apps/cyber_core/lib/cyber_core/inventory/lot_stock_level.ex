defmodule CyberCore.Inventory.LotStockLevel do
  @moduledoc """
  Складови наличности по партиди.
  Свързва партида с конкретен склад и количество.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "lot_stock_levels" do
    field :tenant_id, :integer
    field :quantity_on_hand, :decimal
    field :quantity_reserved, :decimal, default: 0
    field :quantity_available, :decimal, virtual: true

    # Връзки
    belongs_to :lot, CyberCore.Inventory.Lot
    belongs_to :warehouse, CyberCore.Inventory.Warehouse
    belongs_to :location, CyberCore.Inventory.WarehouseLocation

    timestamps()
  end

  @doc false
  def changeset(lot_stock_level, attrs) do
    lot_stock_level
    |> cast(attrs, [
      :tenant_id,
      :lot_id,
      :warehouse_id,
      :location_id,
      :quantity_on_hand,
      :quantity_reserved
    ])
    |> validate_required([:tenant_id, :lot_id, :warehouse_id, :quantity_on_hand])
    |> validate_number(:quantity_on_hand, greater_than_or_equal_to: 0)
    |> validate_number(:quantity_reserved, greater_than_or_equal_to: 0)
    |> validate_reserved_quantity()
    |> unique_constraint([:tenant_id, :lot_id, :warehouse_id, :location_id],
      name: :lot_stock_levels_tenant_id_lot_id_warehouse_id_location_id_index
    )
  end

  defp validate_reserved_quantity(changeset) do
    quantity_on_hand = get_field(changeset, :quantity_on_hand) || Decimal.new(0)
    quantity_reserved = get_field(changeset, :quantity_reserved) || Decimal.new(0)

    if Decimal.gt?(quantity_reserved, quantity_on_hand) do
      add_error(
        changeset,
        :quantity_reserved,
        "не може да бъде повече от наличното количество"
      )
    else
      changeset
    end
  end

  @doc """
  Изчислява достъпното количество (налично - резервирано).
  """
  def calculate_available(%__MODULE__{} = level) do
    available =
      Decimal.sub(
        level.quantity_on_hand || Decimal.new(0),
        level.quantity_reserved || Decimal.new(0)
      )

    %{level | quantity_available: available}
  end
end
