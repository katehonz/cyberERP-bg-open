defmodule CyberCore.Repo.Migrations.CreateIntegrationSettings do
  use Ecto.Migration

  def change do
    create table(:integration_settings) do
      add :tenant_id, :integer, null: false
      add :integration_type, :string, null: false
      add :name, :string, null: false
      add :enabled, :boolean, default: true

      # Encrypted credentials
      add :config, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integration_settings, [:tenant_id, :integration_type, :name])
    create index(:integration_settings, [:tenant_id])
    create index(:integration_settings, [:integration_type])
  end
end
