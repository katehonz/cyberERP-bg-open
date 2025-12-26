defmodule CyberCore.Repo.Migrations.CreatePurchaseOrders do
  use Ecto.Migration

  def change do
    create table(:purchase_orders) do
      add :tenant_id, :integer, null: false

      # Номериране
      add :order_no, :string, size: 50, null: false
      add :status, :string, size: 20, default: "draft", null: false

      # Дати
      add :order_date, :date, null: false
      add :expected_date, :date
      add :received_date, :date

      # Връзки
      add :supplier_id, references(:contacts, on_delete: :restrict), null: false

      # Данни за доставчик
      add :supplier_name, :string, size: 200, null: false
      add :supplier_address, :text
      add :supplier_vat_number, :string, size: 50

      # Финансови данни
      add :subtotal, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :tax_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :currency, :string, size: 3, default: "BGN", null: false

      # Допълнителна информация
      add :notes, :text
      add :payment_terms, :text
      add :reference, :string, size: 100

      timestamps()
    end

    create index(:purchase_orders, [:tenant_id])
    create index(:purchase_orders, [:supplier_id])
    create unique_index(:purchase_orders, [:tenant_id, :order_no])
    create index(:purchase_orders, [:order_date])
    create index(:purchase_orders, [:status])
  end
end
