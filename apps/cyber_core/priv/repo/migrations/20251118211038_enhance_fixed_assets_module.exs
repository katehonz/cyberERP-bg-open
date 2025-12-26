defmodule CyberCore.Repo.Migrations.EnhanceFixedAssetsModule do
  use Ecto.Migration

  def change do
    # Add new fields to assets table for Bulgarian tax compliance
    alter table(:assets) do
      # Bulgarian Tax Category (ЗКПО)
      # I, II, III, IV, V, VI, VII
      add :tax_category, :string
      # Annual rate according to ЗКПО
      add :tax_depreciation_rate, :decimal
      # Can differ from tax rate
      add :accounting_depreciation_rate, :decimal

      # Additional asset information
      # Инвентарен номер
      add :inventory_number, :string
      # Сериен номер
      add :serial_number, :string
      # Местонахождение
      add :location, :string
      # Материално отговорно лице
      add :responsible_person, :string
      # Доставчик
      add :supplier_id, references(:contacts, on_delete: :nilify_all)
      # Номер на фактура за придобиване
      add :invoice_number, :string
      # Дата на фактура
      add :invoice_date, :date

      # Disposal information
      # Дата на извеждане
      add :disposal_date, :date
      # Причина за извеждане
      add :disposal_reason, :string
      # Стойност при извеждане
      add :disposal_value, :decimal
      add :disposal_journal_entry_id, references(:journal_entries, on_delete: :nilify_all)

      # Accumulated depreciation
      add :accumulated_depreciation_account_id, references(:accounts, on_delete: :nilify_all)

      # Notes and attachments
      add :notes, :text
      # For storing file references
      add :attachments, :jsonb
    end

    create index(:assets, [:tax_category])
    create index(:assets, [:status])
    create index(:assets, [:inventory_number])
    create index(:assets, [:supplier_id])

    create unique_index(:assets, [:tenant_id, :inventory_number],
             where: "inventory_number IS NOT NULL",
             name: :assets_tenant_id_inventory_number_index
           )

    # Enhance depreciation schedules with tax/accounting separation
    alter table(:asset_depreciation_schedules) do
      # "accounting" or "tax"
      add :depreciation_type, :string, default: "accounting"
      # Счетоводна амортизация
      add :accounting_amount, :decimal
      # Данъчна амортизация
      add :tax_amount, :decimal
      # Натрупана амортизация към датата
      add :accumulated_depreciation, :decimal
      # Балансова стойност след амортизацията
      add :book_value, :decimal
    end

    create index(:asset_depreciation_schedules, [:depreciation_type])
    create index(:asset_depreciation_schedules, [:period_date])
    create index(:asset_depreciation_schedules, [:status])
  end
end
