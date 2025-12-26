defmodule CyberCore.Repo.Migrations.AddRatesToProductionOrderOperations do
  use Ecto.Migration

  def change do
    alter table(:production_order_operations) do
      add :labor_rate_per_hour, :decimal, precision: 15, scale: 4, default: 0.0
      add :machine_rate_per_hour, :decimal, precision: 15, scale: 4, default: 0.0
    end
  end
end