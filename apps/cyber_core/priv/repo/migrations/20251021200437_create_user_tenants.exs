defmodule CyberCore.Repo.Migrations.CreateUserTenants do
  use Ecto.Migration

  def change do
    create table(:user_tenants) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :role, :string, default: "user", null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:user_tenants, [:user_id, :tenant_id])
    create index(:user_tenants, [:tenant_id])
  end
end
