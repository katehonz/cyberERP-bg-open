defmodule CyberCore.Inventory.WarehouseLocation do
  @moduledoc """
  Складови локации/зони - физическо местоположение в склада.
  Примери: Стелаж-А-Рафт-3, Зона-Б-12, Витрина-1 и т.н.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "warehouse_locations" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :description, :string
    field :zone, :string
    field :aisle, :string
    field :rack, :string
    field :shelf, :string
    field :bin, :string
    field :barcode, :string
    field :is_active, :boolean, default: true
    field :capacity, :decimal
    field :capacity_unit, :string

    # Връзки
    belongs_to :warehouse, CyberCore.Inventory.Warehouse

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [
      :tenant_id,
      :warehouse_id,
      :code,
      :name,
      :description,
      :zone,
      :aisle,
      :rack,
      :shelf,
      :bin,
      :barcode,
      :is_active,
      :capacity,
      :capacity_unit
    ])
    |> validate_required([:tenant_id, :warehouse_id, :code, :name])
    |> validate_length(:code, min: 1, max: 50)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:capacity, greater_than: 0)
    |> unique_constraint([:tenant_id, :warehouse_id, :code],
      name: :warehouse_locations_tenant_id_warehouse_id_code_index
    )
  end

  @doc """
  Генерира пълен адрес на локацията в склада.
  """
  def full_address(%__MODULE__{} = location) do
    parts =
      [
        location.zone && "Зона: #{location.zone}",
        location.aisle && "Алея: #{location.aisle}",
        location.rack && "Стелаж: #{location.rack}",
        location.shelf && "Рафт: #{location.shelf}",
        location.bin && "Кутия: #{location.bin}"
      ]
      |> Enum.filter(& &1)

    if Enum.empty?(parts) do
      location.name
    else
      "#{location.name} (#{Enum.join(parts, ", ")})"
    end
  end
end
