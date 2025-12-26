defmodule CyberCore.Repo.Migrations.AddVatCodesToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      # Кодове според ППЗДДС (Правилник за прилагане на ЗДДС)
      add :vat_document_type, :string,
        size: 10,
        comment: "Bulgarian VAT document type code (01-95) according to PPZDDS"

      add :vat_purchase_operation, :string,
        size: 10,
        comment: "Bulgarian VAT purchase operation code (0-6)"

      add :vat_sales_operation, :string,
        size: 10,
        comment: "Bulgarian VAT sales operation code (0-10, 9001-9002)"

      add :vat_additional_operation, :string,
        size: 10,
        comment: "Bulgarian VAT additional operation code (0-8)"

      add :vat_additional_data, :text, comment: "Additional data for VAT reporting"
    end

    create index(:invoices, [:vat_document_type])
  end
end
