defmodule CyberCore.Repo.Migrations.AddProductFields do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :barcode, :string
      add :tax_rate, :decimal, default: 20.0
      add :is_active, :boolean, default: true
      add :track_inventory, :boolean, default: true
    end

    create index(:products, [:barcode])
  end
end
