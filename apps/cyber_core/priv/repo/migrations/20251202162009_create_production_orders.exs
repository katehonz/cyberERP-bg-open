defmodule CyberCore.Repo.Migrations.CreateProductionOrders do
  use Ecto.Migration

  def change do
    create table(:production_orders) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :recipe_id, references(:recipes, on_delete: :nilify_all)
      add :output_product_id, references(:products, on_delete: :nilify_all)
      add :order_number, :string, null: false
      add :description, :string
      add :quantity_to_produce, :decimal, precision: 15, scale: 4, default: 1.0
      add :quantity_produced, :decimal, precision: 15, scale: 4, default: 0.0
      add :unit, :string
      add :status, :string, default: "planned"
      add :planned_date, :date
      add :start_date, :date
      add :completion_date, :date
      add :notes, :string

      timestamps()
    end

    create index(:production_orders, [:tenant_id])
    create unique_index(:production_orders, [:tenant_id, :order_number])

    create table(:production_order_items) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :production_order_id, references(:production_orders, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :nilify_all)
      add :description, :string
      add :quantity, :decimal, precision: 15, scale: 4
      add :unit, :string

      timestamps()
    end

    create index(:production_order_items, [:tenant_id])
    create index(:production_order_items, [:production_order_id])
    create index(:production_order_items, [:product_id])
  end
end
