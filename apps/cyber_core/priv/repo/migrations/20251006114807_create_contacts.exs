defmodule CyberCore.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :citext
      add :phone, :string
      add :company, :string
      add :address, :string
      add :city, :string
      add :country, :string
      add :is_company, :boolean, null: false, default: false

      timestamps()
    end

    create index(:contacts, [:tenant_id])
    create index(:contacts, [:tenant_id, :is_company])
  end
end
