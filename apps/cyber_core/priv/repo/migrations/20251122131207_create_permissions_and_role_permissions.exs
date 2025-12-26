defmodule CyberCore.Repo.Migrations.CreatePermissionsAndRolePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :description, :string

      timestamps()
    end

    create unique_index(:permissions, [:name])

    create table(:role_permissions) do
      add :role, :string, null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:role_permissions, [:role])
    create unique_index(:role_permissions, [:role, :permission_id])
  end
end
