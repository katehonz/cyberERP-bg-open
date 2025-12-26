defmodule CyberCore.Repo.Migrations.CreateStockMovements do
  use Ecto.Migration

  def change do
    create table(:stock_movements) do
      add :tenant_id, :integer, null: false
      add :document_no, :string, size: 50
      add :movement_type, :string, size: 20, null: false
      add :movement_date, :naive_datetime, null: false
      add :status, :string, size: 20, default: "draft", null: false

      # Връзки
      add :product_id, references(:products, on_delete: :restrict), null: false
      add :warehouse_id, references(:warehouses, on_delete: :restrict), null: false
      add :to_warehouse_id, references(:warehouses, on_delete: :restrict)

      # Количества и суми
      add :quantity, :decimal, precision: 15, scale: 4, null: false
      add :unit_price, :decimal, precision: 15, scale: 2
      add :total_amount, :decimal, precision: 15, scale: 2

      # Референция
      add :reference_type, :string, size: 50
      add :reference_id, :integer

      add :notes, :text

      timestamps()
    end

    create index(:stock_movements, [:tenant_id])
    create index(:stock_movements, [:product_id])
    create index(:stock_movements, [:warehouse_id])
    create index(:stock_movements, [:to_warehouse_id])
    create index(:stock_movements, [:movement_date])
    create index(:stock_movements, [:movement_type])
    create index(:stock_movements, [:status])
    create index(:stock_movements, [:reference_type, :reference_id])
  end
end
