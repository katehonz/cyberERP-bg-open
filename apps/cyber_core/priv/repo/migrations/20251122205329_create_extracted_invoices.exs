defmodule CyberCore.Repo.Migrations.CreateExtractedInvoices do
  use Ecto.Migration

  def change do
    create table(:extracted_invoices) do
      add :tenant_id, :integer, null: false
      add :document_upload_id, references(:document_uploads, on_delete: :delete_all), null: false

      # Invoice metadata
      add :invoice_type, :string, null: false
      add :status, :string, null: false, default: "pending_review"
      add :confidence_score, :decimal, precision: 5, scale: 4

      # Extracted invoice fields
      add :invoice_number, :string
      add :invoice_date, :date
      add :due_date, :date

      # Vendor/Customer info
      add :vendor_name, :string
      add :vendor_address, :text
      add :vendor_vat_number, :string
      add :customer_name, :string
      add :customer_address, :text
      add :customer_vat_number, :string

      # Financial fields
      add :subtotal, :decimal, precision: 15, scale: 2
      add :tax_amount, :decimal, precision: 15, scale: 2
      add :total_amount, :decimal, precision: 15, scale: 2
      add :currency, :string, default: "BGN"

      # Line items as JSONB
      add :line_items, {:array, :map}, default: []

      # Raw Azure data
      add :raw_data, :map

      # Approval tracking
      add :approved_by_id, references(:users, on_delete: :nilify_all)
      add :approved_at, :utc_datetime
      add :rejection_reason, :text

      # Link to converted invoice
      add :converted_invoice_id, :integer
      add :converted_invoice_type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:extracted_invoices, [:tenant_id])
    create index(:extracted_invoices, [:document_upload_id])
    create index(:extracted_invoices, [:status])
    create index(:extracted_invoices, [:invoice_type])
  end
end
