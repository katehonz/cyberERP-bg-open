defmodule CyberCore.Repo.Migrations.CreateOssVatRates do
  use Ecto.Migration

  def change do
    create table(:oss_vat_rates, primary_key: false) do
      add :country_code, :string, size: 2, primary_key: true
      add :rate, :decimal, null: false
      add :country_name, :string, null: false

      timestamps()
    end
  end
end
