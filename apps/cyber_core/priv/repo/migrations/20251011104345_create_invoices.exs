defmodule CyberCore.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add :tenant_id, :integer, null: false

      # Номериране и тип
      add :invoice_no, :string, size: 50, null: false
      add :invoice_type, :string, size: 20, default: "standard", null: false
      add :status, :string, size: 20, default: "draft", null: false

      # Дати
      add :issue_date, :date, null: false
      add :due_date, :date
      add :tax_event_date, :date

      # Връзки
      add :contact_id, references(:contacts, on_delete: :restrict), null: false
      add :parent_invoice_id, references(:invoices, on_delete: :nilify_all)

      # Данни за фактуриране
      add :billing_name, :string, size: 200, null: false
      add :billing_address, :text
      add :billing_vat_number, :string, size: 50
      add :billing_company_id, :string, size: 50

      # Финансови данни
      add :subtotal, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :tax_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :paid_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :currency, :string, size: 3, default: "BGN", null: false

      # Допълнителна информация
      add :notes, :text
      add :payment_terms, :text
      add :reference, :string, size: 100

      timestamps()
    end

    create index(:invoices, [:tenant_id])
    create index(:invoices, [:contact_id])
    create unique_index(:invoices, [:tenant_id, :invoice_no])
    create index(:invoices, [:issue_date])
    create index(:invoices, [:status])
    create index(:invoices, [:invoice_type])
  end
end
