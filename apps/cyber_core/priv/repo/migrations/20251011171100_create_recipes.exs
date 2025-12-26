defmodule CyberCore.Repo.Migrations.CreateRecipes do
  use Ecto.Migration

  def change do
    create table(:recipes) do
      add :tenant_id, :integer, null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :output_product_id, references(:products, on_delete: :restrict)
      add :output_quantity, :decimal, precision: 15, scale: 4, null: false, default: 1
      add :unit, :string, size: 20, null: false, default: "бр."
      add :version, :string, default: "1.0"
      add :is_active, :boolean, default: true
      add :notes, :text

      timestamps()
    end

    create unique_index(:recipes, [:tenant_id, :code])
    create index(:recipes, [:tenant_id])
    create index(:recipes, [:output_product_id])

    create table(:recipe_items) do
      add :tenant_id, :integer, null: false
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict), null: false
      add :line_no, :integer, null: false
      add :description, :string
      add :quantity, :decimal, precision: 15, scale: 4, null: false
      add :unit, :string, size: 20, null: false, default: "бр."
      add :wastage_percent, :decimal, precision: 5, scale: 2, default: 0
      add :notes, :text

      timestamps()
    end

    create index(:recipe_items, [:tenant_id])
    create index(:recipe_items, [:recipe_id])
    create index(:recipe_items, [:product_id])
    create unique_index(:recipe_items, [:recipe_id, :line_no])
  end
end
