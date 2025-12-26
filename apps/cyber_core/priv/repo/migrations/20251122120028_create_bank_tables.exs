defmodule CyberCore.Repo.Migrations.CreateBankTables do
  use Ecto.Migration

  def change do
    # 1. Bank Profiles - конфигурация на банкови сметки
    create table(:bank_profiles) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :iban, :string
      add :bic, :string
      add :bank_name, :string

      # Счетоводни настройки
      add :bank_account_id, references(:accounts, on_delete: :restrict), null: false
      add :buffer_account_id, references(:accounts, on_delete: :restrict), null: false
      add :currency_code, :string, size: 3, null: false, default: "BGN"

      # Настройки за импорт
      # mt940, camt053_wise, camt053_revolut, ccb_csv, xml
      add :import_format, :string
      add :is_active, :boolean, default: true, null: false

      # Salt Edge integration
      add :saltedge_connection_id, :string
      add :saltedge_account_id, :string
      add :auto_sync_enabled, :boolean, default: false, null: false
      add :last_synced_at, :utc_datetime

      # Metadata
      # JSON settings
      add :settings, :map
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:bank_profiles, [:tenant_id])
    create index(:bank_profiles, [:iban])
    create index(:bank_profiles, [:saltedge_connection_id])
    create unique_index(:bank_profiles, [:tenant_id, :iban])

    # 2. Bank Connections - Salt Edge connections
    create table(:bank_connections) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :bank_profile_id, references(:bank_profiles, on_delete: :delete_all)

      # Salt Edge credentials
      add :saltedge_connection_id, :string, null: false
      add :saltedge_customer_id, :string, null: false
      # unicredit_bg, dskbank_bg, etc.
      add :provider_code, :string
      add :provider_name, :string

      # Connection status
      # active, inactive, reconnect_required
      add :status, :string, null: false, default: "active"
      add :consent_expires_at, :utc_datetime
      add :last_success_at, :utc_datetime
      add :last_attempt_at, :utc_datetime
      add :last_error, :text

      # Metadata
      # JSON metadata from Salt Edge
      add :metadata, :map
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:bank_connections, [:tenant_id])
    create index(:bank_connections, [:bank_profile_id])
    create unique_index(:bank_connections, [:saltedge_connection_id])
    create index(:bank_connections, [:status])

    # 3. Bank Imports - история на импорти
    create table(:bank_imports) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :bank_profile_id, references(:bank_profiles, on_delete: :restrict), null: false

      # Import details
      # saltedge_auto, saltedge_manual, file_upload
      add :import_type, :string, null: false
      add :file_name, :string
      # mt940, camt053, csv, saltedge_api
      add :import_format, :string
      add :imported_at, :utc_datetime, null: false

      # Statistics
      add :transactions_count, :integer, default: 0, null: false
      add :total_credit, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :total_debit, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :created_journal_entries, :integer, default: 0, null: false

      # References
      add :journal_entry_ids, {:array, :integer}, default: []

      # Status
      # in_progress, completed, failed
      add :status, :string, null: false, default: "in_progress"
      add :error_message, :text

      # Period
      add :period_from, :date
      add :period_to, :date

      # Salt Edge specific
      add :saltedge_attempt_id, :string

      # Metadata
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:bank_imports, [:tenant_id])
    create index(:bank_imports, [:bank_profile_id])
    create index(:bank_imports, [:status])
    create index(:bank_imports, [:import_type])
    create index(:bank_imports, [:imported_at])
    create index(:bank_imports, [:period_from, :period_to])

    # 4. Bank Transactions (temporary storage before journal entry creation)
    create table(:bank_transactions) do
      add :bank_import_id, references(:bank_imports, on_delete: :delete_all), null: false
      add :bank_profile_id, references(:bank_profiles, on_delete: :restrict), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      # Transaction data
      add :booking_date, :date, null: false
      add :value_date, :date
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :currency, :string, size: 3, null: false
      add :is_credit, :boolean, null: false

      # Description
      add :description, :text
      add :reference, :string
      # Salt Edge transaction ID or bank reference
      add :transaction_id, :string

      # Counterpart info (може да бъде извлечен от Salt Edge или AI)
      add :counterpart_name, :string
      add :counterpart_iban, :string
      add :counterpart_bic, :string

      # Processing
      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all)
      add :is_processed, :boolean, default: false, null: false
      add :processed_at, :utc_datetime

      # Metadata
      # Salt Edge extra data
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:bank_transactions, [:bank_import_id])
    create index(:bank_transactions, [:bank_profile_id])
    create index(:bank_transactions, [:tenant_id])
    create index(:bank_transactions, [:booking_date])
    create index(:bank_transactions, [:is_processed])

    create unique_index(:bank_transactions, [:transaction_id, :bank_profile_id],
             name: :bank_transactions_unique_transaction_idx,
             where: "transaction_id IS NOT NULL"
           )
  end
end
