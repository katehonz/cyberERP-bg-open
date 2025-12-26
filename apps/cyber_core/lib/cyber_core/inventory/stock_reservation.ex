defmodule CyberCore.Inventory.StockReservation do
  @moduledoc """
  Резервации на складови наличности.
  Използва се за резервиране на стока за конкретни поръчки или операции.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @reservation_types ~w(sales_order production_order transfer service)
  @statuses ~w(active fulfilled cancelled expired)

  schema "stock_reservations" do
    field :tenant_id, :integer
    field :reservation_number, :string
    field :reservation_type, :string
    field :status, :string, default: "active"
    field :quantity, :decimal
    field :quantity_fulfilled, :decimal, default: 0
    field :reserved_until, :naive_datetime
    field :reference_type, :string
    field :reference_id, :integer
    field :notes, :string

    # Връзки
    belongs_to :product, CyberCore.Inventory.Product
    belongs_to :warehouse, CyberCore.Inventory.Warehouse
    belongs_to :lot, CyberCore.Inventory.Lot
    field :created_by_id, :integer

    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [
      :tenant_id,
      :product_id,
      :warehouse_id,
      :lot_id,
      :reservation_number,
      :reservation_type,
      :status,
      :quantity,
      :quantity_fulfilled,
      :reserved_until,
      :reference_type,
      :reference_id,
      :notes,
      :created_by_id
    ])
    |> validate_required([
      :tenant_id,
      :product_id,
      :warehouse_id,
      :reservation_type,
      :quantity
    ])
    |> validate_inclusion(:reservation_type, @reservation_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:quantity_fulfilled, greater_than_or_equal_to: 0)
    |> validate_fulfilled_quantity()
    |> generate_reservation_number()
  end

  defp validate_fulfilled_quantity(changeset) do
    quantity = get_field(changeset, :quantity) || Decimal.new(0)
    quantity_fulfilled = get_field(changeset, :quantity_fulfilled) || Decimal.new(0)

    if Decimal.gt?(quantity_fulfilled, quantity) do
      add_error(
        changeset,
        :quantity_fulfilled,
        "не може да бъде повече от резервираното количество"
      )
    else
      changeset
    end
  end

  defp generate_reservation_number(changeset) do
    case get_field(changeset, :reservation_number) do
      nil ->
        number = "RES-#{System.unique_integer([:positive])}"
        put_change(changeset, :reservation_number, number)

      _ ->
        changeset
    end
  end

  @doc """
  Проверява дали резервацията е изтекла.
  """
  def expired?(%__MODULE__{reserved_until: nil}), do: false

  def expired?(%__MODULE__{reserved_until: reserved_until}) do
    NaiveDateTime.compare(NaiveDateTime.utc_now(), reserved_until) == :gt
  end

  @doc """
  Изчислява оставащото за изпълнение количество.
  """
  def remaining_quantity(%__MODULE__{} = reservation) do
    Decimal.sub(
      reservation.quantity || Decimal.new(0),
      reservation.quantity_fulfilled || Decimal.new(0)
    )
  end
end
