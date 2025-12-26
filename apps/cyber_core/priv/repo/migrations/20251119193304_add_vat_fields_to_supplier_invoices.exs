defmodule CyberCore.Repo.Migrations.AddVatFieldsToSupplierInvoices do
  use Ecto.Migration

  def change do
    alter table(:supplier_invoices) do
      add :vat_document_type, :string
      add :vat_purchase_operation, :string
      add :vat_additional_data, :text
    end
  end
end
