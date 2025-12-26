defmodule CyberCore.Repo.Migrations.CreateVatRegisters do
  use Ecto.Migration

  def change do
    # Дневник продажби (Sales Register)
    create table(:vat_sales_register) do
      add :tenant_id, :integer, null: false
      add :period_year, :integer, null: false
      add :period_month, :integer, null: false

      # Връзка към фактура
      add :invoice_id, references(:invoices, on_delete: :restrict)

      # Данни за документа
      add :document_date, :date, null: false
      add :tax_event_date, :date, null: false
      # ППЗДДС код (01, 02, 03...)
      add :document_type, :string, null: false
      add :document_number, :string, null: false
      # Код на операция (0-10, 9001-9002)
      add :sales_operation, :string

      # Данни за контрагент
      add :recipient_name, :string, null: false
      add :recipient_vat_number, :string
      add :recipient_country, :string, default: "BG"
      add :recipient_eik, :string

      # Финансови данни
      add :taxable_base, :decimal, precision: 15, scale: 2, null: false
      add :vat_rate, :decimal, precision: 5, scale: 2, null: false
      add :vat_amount, :decimal, precision: 15, scale: 2, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, null: false

      # Забележки
      add :notes, :text

      timestamps()
    end

    create index(:vat_sales_register, [:tenant_id, :period_year, :period_month])
    create index(:vat_sales_register, [:tenant_id, :document_date])
    create index(:vat_sales_register, [:tenant_id, :invoice_id])
    create index(:vat_sales_register, [:recipient_vat_number])

    # Дневник покупки (Purchase Register)
    create table(:vat_purchase_register) do
      add :tenant_id, :integer, null: false
      add :period_year, :integer, null: false
      add :period_month, :integer, null: false

      # Връзка към документ (може да е invoice за входящи фактури)
      add :document_id, :integer
      # "invoices", "bank_transactions", etc.
      add :document_type_table, :string

      # Данни за документа
      add :document_date, :date, null: false
      add :tax_event_date, :date, null: false
      # ППЗДДС код
      add :document_type, :string, null: false
      add :document_number, :string, null: false
      # Код на операция (0-6)
      add :purchase_operation, :string

      # Данни за контрагент (доставчик)
      add :supplier_name, :string, null: false
      add :supplier_vat_number, :string
      add :supplier_country, :string, default: "BG"
      add :supplier_eik, :string

      # Финансови данни
      add :taxable_base, :decimal, precision: 15, scale: 2, null: false
      add :vat_rate, :decimal, precision: 5, scale: 2, null: false
      add :vat_amount, :decimal, precision: 15, scale: 2, null: false
      add :total_amount, :decimal, precision: 15, scale: 2, null: false

      # За приспадане на ДДС
      add :is_deductible, :boolean, default: true
      add :deductible_vat_amount, :decimal, precision: 15, scale: 2

      # Забележки
      add :notes, :text

      timestamps()
    end

    create index(:vat_purchase_register, [:tenant_id, :period_year, :period_month])
    create index(:vat_purchase_register, [:tenant_id, :document_date])
    create index(:vat_purchase_register, [:supplier_vat_number])

    # ДДС декларация (VAT Return)
    create table(:vat_returns) do
      add :tenant_id, :integer, null: false
      add :period_year, :integer, null: false
      add :period_month, :integer, null: false

      # Статус
      # draft, submitted, accepted
      add :status, :string, null: false, default: "draft"

      # Начислен ДДС по продажби
      add :total_sales_taxable, :decimal, precision: 15, scale: 2, default: "0"
      add :total_sales_vat, :decimal, precision: 15, scale: 2, default: "0"

      # Приспадащ се ДДС по покупки
      add :total_purchases_taxable, :decimal, precision: 15, scale: 2, default: "0"
      add :total_purchases_vat, :decimal, precision: 15, scale: 2, default: "0"
      add :total_deductible_vat, :decimal, precision: 15, scale: 2, default: "0"

      # Резултат
      # За внасяне
      add :vat_payable, :decimal, precision: 15, scale: 2, default: "0"
      # За възстановяване
      add :vat_refundable, :decimal, precision: 15, scale: 2, default: "0"

      # Дати
      add :submission_date, :date
      add :due_date, :date

      # Забележки
      add :notes, :text

      timestamps()
    end

    create unique_index(:vat_returns, [:tenant_id, :period_year, :period_month])
  end
end
