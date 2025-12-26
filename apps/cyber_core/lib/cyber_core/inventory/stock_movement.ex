defmodule CyberCore.Inventory.StockMovement do
  @moduledoc """
  Складови движения - приход, разход, прехвърляне между складове.

  ## Типове движения

  Входящи:
  - `in` - Приход от доставчик
  - `surplus` - Излишък при инвентаризация
  - `production_receipt` - Приход от производство
  - `opening_balance` - Начално салдо
  - `purchase` - Покупка

  Изходящи:
  - `out` - Разход (продажба)
  - `shortage` - Липса при инвентаризация
  - `scrapping` - Брак
  - `production_issue` - Изписване за производство
  - `sale` - Продажба

  Други:
  - `transfer` - Прехвърляне между складове
  - `adjustment` - Корекция
  """
  use Ecto.Schema
  import Ecto.Changeset

  @movement_types ~w(in out transfer adjustment surplus shortage scrapping production_receipt production_issue opening_balance purchase sale)
  @statuses ~w(draft confirmed cancelled)

  schema "stock_movements" do
    field :tenant_id, :integer
    field :document_no, :string
    field :movement_type, :string
    field :movement_date, :date
    field :status, :string, default: "draft"
    field :notes, :string
    field :reference_type, :string
    field :reference_id, :integer

    # Връзки
    belongs_to :product, CyberCore.Inventory.Product
    belongs_to :warehouse, CyberCore.Inventory.Warehouse
    belongs_to :to_warehouse, CyberCore.Inventory.Warehouse

    # Количества и цени
    field :quantity, :decimal
    field :unit_cost, :decimal           # Входна цена (при приемане)
    field :unit_price, :decimal          # Продажна цена (при продажба)
    field :total_amount, :decimal

    # Изчислена себестойност (попълва се от CostingEngine)
    field :computed_unit_cost, :decimal
    field :computed_total_cost, :decimal

    timestamps()
  end

  @doc false
  def changeset(movement, attrs) do
    movement
    |> cast(attrs, [
      :tenant_id,
      :document_no,
      :movement_type,
      :movement_date,
      :status,
      :notes,
      :reference_type,
      :reference_id,
      :product_id,
      :warehouse_id,
      :to_warehouse_id,
      :quantity,
      :unit_cost,
      :unit_price,
      :total_amount,
      :computed_unit_cost,
      :computed_total_cost
    ])
    |> validate_required([
      :tenant_id,
      :movement_type,
      :movement_date,
      :product_id,
      :warehouse_id,
      :quantity
    ])
    |> validate_inclusion(:movement_type, @movement_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_transfer_warehouse()
    |> calculate_total()
  end

  defp validate_transfer_warehouse(changeset) do
    movement_type = get_field(changeset, :movement_type)
    to_warehouse_id = get_field(changeset, :to_warehouse_id)

    if movement_type == "transfer" and is_nil(to_warehouse_id) do
      add_error(changeset, :to_warehouse_id, "е задължително за трансфер")
    else
      changeset
    end
  end

  defp calculate_total(changeset) do
    quantity = get_field(changeset, :quantity)
    unit_price = get_field(changeset, :unit_price)

    if quantity && unit_price do
      total = Decimal.mult(quantity, unit_price)
      put_change(changeset, :total_amount, total)
    else
      changeset
    end
  end
end
