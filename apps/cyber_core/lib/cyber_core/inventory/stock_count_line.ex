defmodule CyberCore.Inventory.StockCountLine do
  @moduledoc """
  Редове от инвентаризация - записва се системното и физическото количество.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "stock_count_lines" do
    field :line_no, :integer
    field :system_quantity, :decimal
    field :counted_quantity, :decimal
    field :variance, :decimal, virtual: true
    field :variance_percent, :float, virtual: true
    field :notes, :string

    # Връзки
    belongs_to :stock_count, CyberCore.Inventory.StockCount
    belongs_to :product, CyberCore.Inventory.Product
    belongs_to :lot, CyberCore.Inventory.Lot
    belongs_to :location, CyberCore.Inventory.WarehouseLocation

    timestamps()
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :stock_count_id,
      :product_id,
      :lot_id,
      :location_id,
      :line_no,
      :system_quantity,
      :counted_quantity,
      :notes
    ])
    |> validate_required([:stock_count_id, :product_id, :system_quantity])
    |> validate_number(:system_quantity, greater_than_or_equal_to: 0)
    |> validate_number(:counted_quantity, greater_than_or_equal_to: 0)
  end

  @doc """
  Изчислява отклонението между системното и физическото количество.
  """
  def calculate_variance(%__MODULE__{} = line) do
    system_qty = line.system_quantity || Decimal.new(0)
    counted_qty = line.counted_quantity || Decimal.new(0)

    variance = Decimal.sub(counted_qty, system_qty)

    variance_percent =
      if Decimal.eq?(system_qty, 0) do
        0.0
      else
        variance
        |> Decimal.div(system_qty)
        |> Decimal.mult(100)
        |> Decimal.to_float()
      end

    %{line | variance: variance, variance_percent: variance_percent}
  end
end
