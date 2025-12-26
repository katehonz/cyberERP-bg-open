defmodule CyberCore.Repo.Migrations.CreateAccountingTables do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :category, :string, null: false
      add :normal_balance, :string, null: false
      add :is_active, :boolean, null: false, default: true
      add :metadata, :map

      timestamps()
    end

    create index(:accounts, [:tenant_id])
    create unique_index(:accounts, [:tenant_id, :code])

    create table(:journal_entries) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :entry_no, :string, null: false
      add :entry_date, :utc_datetime, null: false
      add :description, :text
      add :source, :string
      add :status, :string, null: false, default: "draft"

      timestamps()
    end

    create index(:journal_entries, [:tenant_id])
    create index(:journal_entries, [:tenant_id, :entry_date])
    create unique_index(:journal_entries, [:tenant_id, :entry_no])

    create table(:journal_lines) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :journal_entry_id, references(:journal_entries, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :restrict), null: false
      add :description, :text
      add :debit, :decimal, null: false, default: 0
      add :credit, :decimal, null: false, default: 0
      add :currency, :string, null: false

      timestamps()
    end

    create index(:journal_lines, [:tenant_id])
    create index(:journal_lines, [:journal_entry_id])
    create index(:journal_lines, [:account_id])

    create table(:assets) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :category, :string, null: false
      add :acquisition_date, :date, null: false
      add :acquisition_cost, :decimal, null: false
      add :salvage_value, :decimal, null: false, default: 0
      add :useful_life_months, :integer, null: false
      add :depreciation_method, :string, null: false
      add :status, :string, null: false, default: "active"
      add :accounting_account_id, references(:accounts, on_delete: :nilify_all)
      add :expense_account_id, references(:accounts, on_delete: :nilify_all)
      add :residual_value, :decimal, null: false, default: 0
      add :metadata, :map

      timestamps()
    end

    create index(:assets, [:tenant_id])
    create unique_index(:assets, [:tenant_id, :code])

    create table(:asset_depreciation_schedules) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all)
      add :period_date, :date, null: false
      add :amount, :decimal, null: false
      add :status, :string, null: false, default: "planned"

      timestamps()
    end

    create index(:asset_depreciation_schedules, [:tenant_id])
    create index(:asset_depreciation_schedules, [:asset_id])

    create table(:financial_accounts) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :kind, :string, null: false
      add :currency, :string, null: false, default: "BGN"
      add :organization_unit, :string
      add :account_id, references(:accounts, on_delete: :nilify_all)
      add :is_active, :boolean, null: false, default: true
      add :metadata, :map

      timestamps()
    end

    create index(:financial_accounts, [:tenant_id])
    create unique_index(:financial_accounts, [:tenant_id, :name])

    create table(:financial_transactions) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      add :financial_account_id, references(:financial_accounts, on_delete: :delete_all),
        null: false

      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all)
      add :transaction_date, :utc_datetime, null: false
      add :reference, :string
      add :direction, :string, null: false
      add :amount, :decimal, null: false
      add :counterparty, :string
      add :notes, :text

      timestamps()
    end

    create index(:financial_transactions, [:tenant_id])
    create index(:financial_transactions, [:financial_account_id])
    create index(:financial_transactions, [:transaction_date])
  end
end
