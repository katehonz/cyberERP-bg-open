defmodule CyberCore.Repo.Migrations.AddAccountFieldsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      # Сметка за разход/себестойност (702 за стоки, 601 за материали, 611 за полуфабрикати)
      add :expense_account_id, references(:accounts, on_delete: :nilify_all)
      # Сметка за приходи от продажба (702 за стоки, null за материали)
      add :revenue_account_id, references(:accounts, on_delete: :nilify_all)
    end

    create index(:products, [:expense_account_id])
    create index(:products, [:revenue_account_id])

    # Преименуваме account_id на inventory_account_id за яснота
    # (account_id остава като inventory сметка - 304, 302, 303)
    execute "COMMENT ON COLUMN products.account_id IS 'Инвентарна сметка (304 стоки, 302 материали, 303 полуфабрикати)'",
            "COMMENT ON COLUMN products.account_id IS NULL"

    execute "COMMENT ON COLUMN products.expense_account_id IS 'Сметка за разход/себестойност (702 стоки, 601 материали, 611 полуфабрикати)'",
            "COMMENT ON COLUMN products.expense_account_id IS NULL"

    execute "COMMENT ON COLUMN products.revenue_account_id IS 'Сметка за приходи от продажба (702 стоки, null за материали)'",
            "COMMENT ON COLUMN products.revenue_account_id IS NULL"
  end
end
