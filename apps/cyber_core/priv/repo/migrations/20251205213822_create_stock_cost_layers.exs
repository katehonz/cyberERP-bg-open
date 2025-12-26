defmodule CyberCore.Repo.Migrations.CreateStockCostLayers do
  use Ecto.Migration

  def change do
    create table(:stock_cost_layers) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :warehouse_id, references(:warehouses, on_delete: :delete_all), null: false

      # Свързано движение (от което идва слоят)
      add :stock_movement_id, references(:stock_movements, on_delete: :delete_all)

      # Дата на слоя (за сортиране при FIFO/LIFO)
      add :layer_date, :date, null: false

      # Количества
      add :original_quantity, :decimal, precision: 15, scale: 4, null: false
      add :remaining_quantity, :decimal, precision: 15, scale: 4, null: false

      # Цена на единица
      add :unit_cost, :decimal, precision: 15, scale: 4, null: false

      # Статус
      add :status, :string, default: "active"  # active, depleted

      timestamps()
    end

    create index(:stock_cost_layers, [:tenant_id])
    create index(:stock_cost_layers, [:product_id, :warehouse_id])
    create index(:stock_cost_layers, [:product_id, :warehouse_id, :layer_date])
    create index(:stock_cost_layers, [:status])

    # Добавяме полета за себестойност към stock_movements
    alter table(:stock_movements) do
      # Входна цена (при приемане)
      add :unit_cost, :decimal, precision: 15, scale: 4
      # Изчислена себестойност (от CostingEngine)
      add :computed_unit_cost, :decimal, precision: 15, scale: 4
      add :computed_total_cost, :decimal, precision: 15, scale: 4
    end

    # stock_levels вече има average_cost и total_value

    execute """
    COMMENT ON TABLE stock_cost_layers IS 'Слоеве за FIFO/LIFO оценка на материалните запаси. Всяка доставка създава слой.'
    """,
    "DROP COMMENT ON TABLE stock_cost_layers"
  end
end
