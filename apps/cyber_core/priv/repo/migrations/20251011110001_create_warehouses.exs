defmodule CyberCore.Repo.Migrations.CreateWarehouses do
  use Ecto.Migration

  def change do
    create table(:warehouses) do
      add :tenant_id, :integer, null: false
      add :code, :string, size: 20, null: false
      add :name, :string, size: 200, null: false
      add :address, :text
      add :city, :string, size: 100
      add :postal_code, :string, size: 20
      add :country, :string, size: 2, default: "BG"
      add :is_active, :boolean, default: true, null: false
      add :notes, :text

      timestamps()
    end

    create index(:warehouses, [:tenant_id])
    create unique_index(:warehouses, [:tenant_id, :code])
    create index(:warehouses, [:is_active])
  end
end
