defmodule CyberCore.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext")

    create table(:tenants) do
      add :name, :string, null: false
      add :slug, :citext, null: false

      timestamps()
    end

    create unique_index(:tenants, [:slug])
  end
end
