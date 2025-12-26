defmodule CyberCore.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :sku, :string, null: false
      add :description, :text
      add :category, :string
      add :quantity, :integer, null: false, default: 0
      add :price, :decimal, null: false, default: 0
      add :cost, :decimal, null: false, default: 0
      add :unit, :string, null: false, default: "piece"

      timestamps()
    end

    create index(:products, [:tenant_id])
    create unique_index(:products, [:tenant_id, :sku])
    create index(:products, [:tenant_id, :category])
  end
end
