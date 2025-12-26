defmodule CyberCore.Repo.Migrations.CreateSupplierInvoices do
  use Ecto.Migration

  def change do
    create table(:supplier_invoices) do
      add :tenant_id, :integer, null: false

      # Номериране
      add :invoice_no, :string, size: 50, null: false
      add :supplier_invoice_no, :string, size: 50, null: false
      add :status, :string, size: 20, default: "draft", null: false

      # Дати
      add :invoice_date, :date, null: false
      add :due_date, :date
      add :received_date, :date
      add :tax_event_date, :date

      # Връзки
      add :supplier_id, references(:contacts, on_delete: :restrict), null: false
      add :purchase_order_id, references(:purchase_orders, on_delete: :nilify_all)

      # Данни за доставчик
      add :supplier_name, :string, size: 200, null: false
      add :supplier_address, :text
      add :supplier_vat_number, :string, size: 50

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

    create index(:supplier_invoices, [:tenant_id])
    create index(:supplier_invoices, [:supplier_id])
    create index(:supplier_invoices, [:purchase_order_id])
    create unique_index(:supplier_invoices, [:tenant_id, :invoice_no])
    create index(:supplier_invoices, [:invoice_date])
    create index(:supplier_invoices, [:status])
  end
end
