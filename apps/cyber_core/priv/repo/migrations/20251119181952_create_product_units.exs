defmodule CyberCore.Repo.Migrations.CreateProductUnits do
  use Ecto.Migration

  def change do
    create table(:product_units) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :measurement_unit_id, references(:measurement_units, on_delete: :restrict), null: false
      add :conversion_factor, :decimal, null: false, precision: 12, scale: 4
      add :is_primary, :boolean, default: false, null: false
      add :is_active, :boolean, default: true, null: false
      add :barcode, :string

      timestamps()
    end

    create unique_index(:product_units, [:product_id, :measurement_unit_id])
    create index(:product_units, [:product_id, :is_primary])
    create unique_index(:product_units, [:barcode], where: "barcode IS NOT NULL")
  end
end
