defmodule CyberCore.Repo.Migrations.CreateBankAccounts do
  use Ecto.Migration

  def change do
    create table(:bank_accounts) do
      add :tenant_id, :integer, null: false

      # Данни за сметката
      add :account_no, :string, null: false
      add :iban, :string, null: false
      add :bic, :string
      add :account_type, :string, default: "current", null: false
      add :currency, :string, size: 3, default: "BGN", null: false
      add :is_active, :boolean, default: true, null: false

      # Данни за банката
      add :bank_name, :string, null: false
      add :bank_code, :string
      add :branch_name, :string

      # Салда
      add :initial_balance, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :current_balance, :decimal, precision: 15, scale: 2, default: 0, null: false

      # Допълнителна информация
      add :notes, :text

      timestamps()
    end

    create unique_index(:bank_accounts, [:tenant_id, :iban])
    create index(:bank_accounts, [:tenant_id])
    create index(:bank_accounts, [:is_active])
  end
end
