defmodule CyberCore.Inventory.Lot do
  @moduledoc """
  Складови партиди - проследяване на партиди/серии с срокове на годност.
  Използва се за проследяване на продукти с партиден номер, дата на производство и срок на годност.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "lots" do
    field :tenant_id, :integer
    field :lot_number, :string
    field :manufacture_date, :date
    field :expiry_date, :date
    field :supplier_lot_number, :string
    field :notes, :string
    field :is_active, :boolean, default: true

    # Връзки
    belongs_to :product, CyberCore.Inventory.Product
    has_many :lot_stock_levels, CyberCore.Inventory.LotStockLevel

    timestamps()
  end

  @doc false
  def changeset(lot, attrs) do
    lot
    |> cast(attrs, [
      :tenant_id,
      :product_id,
      :lot_number,
      :manufacture_date,
      :expiry_date,
      :supplier_lot_number,
      :notes,
      :is_active
    ])
    |> validate_required([:tenant_id, :product_id, :lot_number])
    |> validate_format(:lot_number, ~r/^[A-Z0-9\-\_]+$/i,
      message: "може да съдържа само букви, цифри, тирета и долни черти"
    )
    |> validate_dates()
    |> unique_constraint([:tenant_id, :product_id, :lot_number],
      name: :lots_tenant_id_product_id_lot_number_index
    )
  end

  defp validate_dates(changeset) do
    manufacture_date = get_field(changeset, :manufacture_date)
    expiry_date = get_field(changeset, :expiry_date)

    cond do
      is_nil(manufacture_date) or is_nil(expiry_date) ->
        changeset

      Date.compare(expiry_date, manufacture_date) != :gt ->
        add_error(
          changeset,
          :expiry_date,
          "трябва да бъде след датата на производство"
        )

      true ->
        changeset
    end
  end

  @doc """
  Проверява дали партидата е изтекла.
  """
  def expired?(%__MODULE__{expiry_date: nil}), do: false

  def expired?(%__MODULE__{expiry_date: expiry_date}) do
    Date.compare(Date.utc_today(), expiry_date) == :gt
  end

  @doc """
  Проверява дали партидата изтича скоро (в рамките на дадени дни).
  """
  def expiring_soon?(%__MODULE__{expiry_date: nil}, _days), do: false

  def expiring_soon?(%__MODULE__{expiry_date: expiry_date}, days) do
    threshold = Date.add(Date.utc_today(), days)
    Date.compare(expiry_date, threshold) != :gt
  end
end
