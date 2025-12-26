defmodule CyberCore.Repo.Migrations.AddBankFieldsToExtractedInvoices do
  use Ecto.Migration

  def change do
    alter table(:extracted_invoices) do
      add :vendor_bank_account, :string
      add :vendor_bank_iban, :string
      add :vendor_bank_bic, :string
      add :vendor_bank_name, :string
    end

    # Index for searching by IBAN
    create index(:extracted_invoices, [:vendor_bank_iban])
  end
end
