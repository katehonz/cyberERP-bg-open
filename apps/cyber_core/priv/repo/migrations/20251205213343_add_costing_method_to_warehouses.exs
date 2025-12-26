defmodule CyberCore.Repo.Migrations.AddCostingMethodToWarehouses do
  use Ecto.Migration

  def change do
    alter table(:warehouses) do
      # Метод за оценка на материалните запаси
      # weighted_average - Средно претеглена цена (по подразбиране)
      # fifo - Първа входяща, първа изходяща
      # lifo - Последна входяща, първа изходяща
      add :costing_method, :string, default: "weighted_average"
    end

    execute "COMMENT ON COLUMN warehouses.costing_method IS 'Метод за оценка: weighted_average, fifo, lifo'",
            "COMMENT ON COLUMN warehouses.costing_method IS NULL"
  end
end
