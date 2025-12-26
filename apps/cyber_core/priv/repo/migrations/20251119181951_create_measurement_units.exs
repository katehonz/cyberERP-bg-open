defmodule CyberCore.Repo.Migrations.CreateMeasurementUnits do
  use Ecto.Migration

  def change do
    create table(:measurement_units) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :symbol, :string, null: false
      add :is_base, :boolean, default: false, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:measurement_units, [:tenant_id, :code])
    create index(:measurement_units, [:tenant_id, :is_active])
  end
end
