defmodule CyberCore.Repo.Migrations.CreateSaleItems do
  use Ecto.Migration

  def change do
    create table(:sale_items) do
      add :tenant_id, :integer, null: false
      add :sale_id, references(:sales, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict)
      add :line_no, :integer, null: false
      add :sku, :string
      add :description, :text, null: false
      add :unit, :string, size: 20, null: false, default: "бр."
      add :quantity, :decimal, precision: 15, scale: 4, null: false
      add :unit_price, :decimal, precision: 15, scale: 2, null: false
      add :discount_percent, :decimal, precision: 5, scale: 2, null: false, default: 0
      add :subtotal, :decimal, precision: 15, scale: 2, null: false
      add :tax_rate, :decimal, precision: 5, scale: 2, null: false, default: 20.0
      add :tax_amount, :decimal, precision: 15, scale: 2, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, null: false
      add :notes, :text

      timestamps()
    end

    create index(:sale_items, [:tenant_id])
    create index(:sale_items, [:sale_id])
    create index(:sale_items, [:product_id])
    create unique_index(:sale_items, [:sale_id, :line_no])
  end
end
