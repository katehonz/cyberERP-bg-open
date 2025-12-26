defmodule CyberCore.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :role, :string, null: false, default: "user"

      timestamps()
    end

    create index(:users, [:tenant_id])
    create unique_index(:users, [:tenant_id, :email])
  end
end
