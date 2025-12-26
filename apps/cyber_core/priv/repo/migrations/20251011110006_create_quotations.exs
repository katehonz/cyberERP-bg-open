defmodule CyberCore.Repo.Migrations.CreateQuotations do
  use Ecto.Migration

  def change do
    create table(:quotations) do
      add :tenant_id, :integer, null: false

      # Номериране
      add :quotation_no, :string, size: 50, null: false
      add :status, :string, size: 20, default: "draft", null: false

      # Дати
      add :issue_date, :date, null: false
      add :valid_until, :date, null: false

      # Връзки
      add :contact_id, references(:contacts, on_delete: :restrict), null: false
      add :invoice_id, references(:invoices, on_delete: :nilify_all)

      # Данни за контакт
      add :contact_name, :string, size: 200, null: false
      add :contact_email, :string, size: 200
      add :contact_phone, :string, size: 50

      # Финансови данни
      add :subtotal, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :tax_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
      add :currency, :string, size: 3, default: "BGN", null: false

      # Допълнителна информация
      add :notes, :text
      add :terms_and_conditions, :text

      timestamps()
    end

    create index(:quotations, [:tenant_id])
    create index(:quotations, [:contact_id])
    create unique_index(:quotations, [:tenant_id, :quotation_no])
    create index(:quotations, [:issue_date])
    create index(:quotations, [:status])
  end
end
