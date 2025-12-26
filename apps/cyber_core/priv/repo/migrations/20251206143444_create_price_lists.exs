defmodule CyberCore.Repo.Migrations.CreatePriceLists do
  use Ecto.Migration

  def change do
    create table(:price_lists) do
      add :name, :string, null: false
      add :type, :string, null: false, default: "non_retail"
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :currency_id, references(:currencies, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:price_lists, [:tenant_id, :name], unique: true)

    create table(:price_list_items) do
      add :price, :decimal, precision: 15, scale: 2, null: false
      add :price_list_id, references(:price_lists, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:price_list_items, [:price_list_id, :product_id], unique: true)
    create index(:price_list_items, [:product_id])
  end
end
