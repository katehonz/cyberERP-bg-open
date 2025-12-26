defmodule CyberCore.Repo.Migrations.CreateAccountingSettings do
  use Ecto.Migration

  def change do
    create table(:accounting_settings) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :suppliers_account_id, references(:accounts, on_delete: :nothing)
      add :customers_account_id, references(:accounts, on_delete: :nothing)
      add :cash_account_id, references(:accounts, on_delete: :nothing)
      add :vat_sales_account_id, references(:accounts, on_delete: :nothing)
      add :vat_purchases_account_id, references(:accounts, on_delete: :nothing)
      add :default_income_account_id, references(:accounts, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:accounting_settings, [:tenant_id])
  end
end
