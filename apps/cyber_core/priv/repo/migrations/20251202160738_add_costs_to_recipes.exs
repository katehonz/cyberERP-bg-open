defmodule CyberCore.Repo.Migrations.AddCostsToRecipes do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :production_cost, :decimal, precision: 15, scale: 4, default: 0.0
    end

    alter table(:recipe_items) do
      add :cost, :decimal, precision: 15, scale: 4, default: 0.0
    end
  end
end
