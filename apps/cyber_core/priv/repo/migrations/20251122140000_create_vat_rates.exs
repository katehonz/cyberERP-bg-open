defmodule CyberCore.Repo.Migrations.CreateVatRates do
  use Ecto.Migration

  def change do
    create table(:vat_rates) do
      add :tenant_id, :integer, null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :rate, :decimal, null: false
      add :vat_direction, :string, null: false
      add :is_active, :boolean, default: true, null: false
      add :valid_from, :date, null: false
      add :valid_to, :date

      timestamps()
    end

    create index(:vat_rates, [:tenant_id])
    create unique_index(:vat_rates, [:tenant_id, :code])
  end
end
