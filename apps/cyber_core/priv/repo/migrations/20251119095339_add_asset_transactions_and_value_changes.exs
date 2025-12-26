defmodule CyberCore.Repo.Migrations.AddAssetTransactionsAndValueChanges do
  use Ecto.Migration

  def change do
    # Create asset_transactions table for SAF-T reporting
    create table(:asset_transactions) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false

      # Transaction details
      # 10=ACQ, 20=IMP, 30=DEP, 40=REV, 50=DSP, 60=SCR, 70=TRF, 80=COR
      add :transaction_type, :string, null: false
      add :transaction_date, :date, null: false
      add :description, :text

      # Values
      add :transaction_amount, :decimal, precision: 15, scale: 2, null: false
      # Промяна в придобивна стойност
      add :acquisition_cost_change, :decimal, precision: 15, scale: 2
      # Балансова стойност след транзакцията
      add :book_value_after, :decimal, precision: 15, scale: 2

      # Supplier/Customer for the transaction
      add :supplier_customer_id, references(:contacts, on_delete: :nilify_all)

      # Link to journal entry
      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all)

      # SAF-T specific fields
      add :saft_transaction_id, :string
      add :year, :integer, null: false
      add :month, :integer, null: false

      timestamps()
    end

    create index(:asset_transactions, [:tenant_id])
    create index(:asset_transactions, [:asset_id])
    create index(:asset_transactions, [:transaction_type])
    create index(:asset_transactions, [:transaction_date])
    create index(:asset_transactions, [:year, :month])
    create index(:asset_transactions, [:saft_transaction_id])

    # Add fields to assets table for tracking value changes
    alter table(:assets) do
      # Track месец на промяна на стойността (за SAF-T ValuationDAP)
      # Месец на промяна на стойността
      add :month_value_change, :integer
      # Месец на спиране/възобновяване на начисляването
      add :month_suspension_resumption, :integer
      # Месец на отписване от счетоводен план
      add :month_writeoff_accounting, :integer
      # Месец на отписване от данъчен план
      add :month_writeoff_tax, :integer

      # Track number of months depreciated during the year
      # Брой месеци с начислена амортизация през годината
      add :depreciation_months_current_year, :integer

      # Beginning/End of year values for SAF-T
      add :acquisition_cost_begin_year, :decimal, precision: 15, scale: 2
      add :book_value_begin_year, :decimal, precision: 15, scale: 2
      add :accumulated_depreciation_begin_year, :decimal, precision: 15, scale: 2

      # Start up date (дата на въвеждане в експлоатация)
      add :startup_date, :date
      # Дата на поръчка
      add :purchase_order_date, :date
    end

    # Add indexes
    create index(:assets, [:month_value_change])
    create index(:assets, [:month_writeoff_accounting])
    create index(:assets, [:startup_date])
  end
end
