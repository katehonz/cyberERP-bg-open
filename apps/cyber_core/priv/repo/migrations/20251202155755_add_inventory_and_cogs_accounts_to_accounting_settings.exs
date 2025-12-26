defmodule CyberCore.Repo.Migrations.AddInventoryAndCogsAccountsToAccountingSettings do
  use Ecto.Migration

  def change do
    alter table(:accounting_settings) do
      add :inventory_goods_account_id, references(:accounts, on_delete: :nothing)
      add :inventory_materials_account_id, references(:accounts, on_delete: :nothing)
      add :inventory_produced_account_id, references(:accounts, on_delete: :nothing)
      add :cogs_account_id, references(:accounts, on_delete: :nothing)
    end
  end
end
