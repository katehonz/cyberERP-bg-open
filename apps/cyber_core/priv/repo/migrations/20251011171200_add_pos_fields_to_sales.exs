defmodule CyberCore.Repo.Migrations.AddPosFieldsToSales do
  use Ecto.Migration

  def change do
    alter table(:sales) do
      add :warehouse_id, references(:warehouses, on_delete: :nilify_all)
      add :payment_method, :string
      add :pos_reference, :string
    end

    create index(:sales, [:warehouse_id])
    create index(:sales, [:tenant_id, :pos_reference])
  end
end
