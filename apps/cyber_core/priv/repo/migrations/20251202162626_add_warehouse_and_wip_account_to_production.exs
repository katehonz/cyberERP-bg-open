defmodule CyberCore.Repo.Migrations.AddWarehouseAndWipAccountToProduction do
  use Ecto.Migration

  def change do
    alter table(:production_orders) do
      add :warehouse_id, references(:warehouses, on_delete: :nilify_all)
    end
    
    alter table(:accounting_settings) do
      add :wip_account_id, references(:accounts, on_delete: :nothing)
    end
  end
end
