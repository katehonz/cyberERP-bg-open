defmodule CyberCore.Repo.Migrations.CreateStockLevels do
  use Ecto.Migration

  def change do
    create table(:stock_levels) do
      add :tenant_id, :integer, null: false

      # Връзки
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :warehouse_id, references(:warehouses, on_delete: :delete_all), null: false

      # Количества
      add :quantity_on_hand, :decimal, precision: 15, scale: 4, default: 0, null: false
      add :quantity_reserved, :decimal, precision: 15, scale: 4, default: 0, null: false
      add :quantity_available, :decimal, precision: 15, scale: 4, default: 0, null: false
      add :minimum_quantity, :decimal, precision: 15, scale: 4, default: 0
      add :reorder_point, :decimal, precision: 15, scale: 4, default: 0

      # Стойности
      add :average_cost, :decimal, precision: 15, scale: 2
      add :last_cost, :decimal, precision: 15, scale: 2
      add :total_value, :decimal, precision: 15, scale: 2

      timestamps()
    end

    create index(:stock_levels, [:tenant_id])
    create index(:stock_levels, [:product_id])
    create index(:stock_levels, [:warehouse_id])
    create unique_index(:stock_levels, [:tenant_id, :product_id, :warehouse_id])
  end
end
