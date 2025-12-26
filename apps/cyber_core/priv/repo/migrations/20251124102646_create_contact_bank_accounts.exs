defmodule CyberCore.Repo.Migrations.CreateContactBankAccounts do
  use Ecto.Migration

  def change do
    create table(:contact_bank_accounts) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false

      # Bank account details
      add :iban, :string
      add :bic, :string
      add :bank_name, :string
      add :account_number, :string
      add :currency, :string, default: "BGN"

      # Flags
      add :is_primary, :boolean, default: false, null: false
      add :is_verified, :boolean, default: false, null: false

      # Tracking
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :times_seen, :integer, default: 1, null: false

      # Notes
      add :notes, :text

      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    # Unique constraint: one IBAN per contact (if IBAN exists)
    create unique_index(
             :contact_bank_accounts,
             [:tenant_id, :contact_id, :iban],
             name: :contact_bank_accounts_unique_iban,
             where: "iban IS NOT NULL"
           )

    # For non-IBAN accounts
    create unique_index(
             :contact_bank_accounts,
             [:tenant_id, :contact_id, :account_number],
             name: :contact_bank_accounts_unique_account_number,
             where: "account_number IS NOT NULL AND iban IS NULL"
           )

    # Index for fast IBAN lookup from bank transactions
    create index(:contact_bank_accounts, [:iban], where: "iban IS NOT NULL")

    # Index for account number lookup
    create index(:contact_bank_accounts, [:account_number], where: "account_number IS NOT NULL")

    # Index for tenant
    create index(:contact_bank_accounts, [:tenant_id])

    # Index for contact
    create index(:contact_bank_accounts, [:contact_id])

    # Index for primary accounts
    create index(:contact_bank_accounts, [:contact_id, :is_primary])
  end
end
