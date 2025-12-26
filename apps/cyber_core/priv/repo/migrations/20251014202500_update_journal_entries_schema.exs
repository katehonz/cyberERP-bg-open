defmodule CyberCore.Repo.Migrations.UpdateJournalEntriesSchema do
  use Ecto.Migration

  def change do
    # Rename old columns to new names to match JournalEntry schema
    rename table(:journal_entries), :entry_no, to: :entry_number
    rename table(:journal_entries), :entry_date, to: :old_entry_date

    # Add new fields that exist in schema but not in table
    alter table(:journal_entries) do
      add :document_date, :date
      add :vat_date, :date
      add :accounting_date, :date
      add :document_number, :string
      add :total_amount, :decimal
      add :total_vat_amount, :decimal
      add :is_posted, :boolean, default: false
      add :posted_at, :utc_datetime
      add :posted_by_id, :integer
      add :vat_document_type, :string
      add :vat_purchase_operation, :string
      add :vat_sales_operation, :string
      add :vat_additional_operation, :string
      add :vat_additional_data, :string
      add :created_by_id, :integer

      # Keep old fields nullable for backwards compatibility
      modify :old_entry_date, :utc_datetime, null: true
      modify :status, :string, null: true
      modify :source, :string, null: true
    end

    # Update the unique index to use new column name
    drop_if_exists unique_index(:journal_entries, [:tenant_id, :entry_no])
    create unique_index(:journal_entries, [:tenant_id, :entry_number])
  end
end
