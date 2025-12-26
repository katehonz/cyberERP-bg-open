defmodule CyberCore.Repo.Migrations.CreateInvoiceLines do
  use Ecto.Migration

  def change do
    create table(:invoice_lines) do
      add :tenant_id, :integer, null: false

      # Връзки
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict)

      # Данни за реда
      add :line_no, :integer
      add :description, :text, null: false
      add :quantity, :decimal, precision: 15, scale: 4, null: false
      add :unit_of_measure, :string, size: 20, default: "бр."
      add :unit_price, :decimal, precision: 15, scale: 2, null: false

      # Отстъпки
      add :discount_percent, :decimal, precision: 5, scale: 2, default: 0
      add :discount_amount, :decimal, precision: 15, scale: 2, default: 0

      # Финансови данни
      add :subtotal, :decimal, precision: 15, scale: 2, null: false
      add :tax_rate, :decimal, precision: 5, scale: 2, default: 20.0, null: false
      add :tax_amount, :decimal, precision: 15, scale: 2, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, null: false

      add :notes, :text

      timestamps()
    end

    create index(:invoice_lines, [:tenant_id])
    create index(:invoice_lines, [:invoice_id])
    create index(:invoice_lines, [:product_id])
  end
end
