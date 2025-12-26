defmodule CyberCore.Repo.Migrations.RenameJournalLinesToEntryLines do
  use Ecto.Migration

  def change do
    # Rename the table
    rename table(:journal_lines), to: table(:entry_lines)

    # Rename columns to match EntryLine schema
    rename table(:entry_lines), :debit, to: :debit_amount
    rename table(:entry_lines), :credit, to: :credit_amount
    rename table(:entry_lines), :currency, to: :currency_code

    # Add new fields that exist in EntryLine schema
    alter table(:entry_lines) do
      add :currency_amount, :decimal
      add :exchange_rate, :decimal, default: 1.0
      add :base_amount, :decimal, default: 0.0
      add :vat_amount, :decimal, default: 0.0
      add :vat_rate_id, :integer
      add :quantity, :decimal
      add :unit_of_measure_code, :string
      add :line_order, :integer, default: 1

      # Make currency_code nullable and set default
      modify :currency_code, :string, null: true, default: "BGN"
    end

    # Update indexes to use new table name
    drop_if_exists index(:journal_lines, [:tenant_id])
    drop_if_exists index(:journal_lines, [:journal_entry_id])
    drop_if_exists index(:journal_lines, [:account_id])

    create index(:entry_lines, [:tenant_id])
    create index(:entry_lines, [:journal_entry_id])
    create index(:entry_lines, [:account_id])
    create index(:entry_lines, [:line_order])
  end
end
