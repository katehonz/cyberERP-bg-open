defmodule CyberCore.Repo.Migrations.AddCityToVatRegisters do
  use Ecto.Migration

  def change do
    alter table(:vat_purchase_register) do
      add :supplier_city, :string, size: 50
    end

    alter table(:vat_sales_register) do
      add :recipient_city, :string, size: 50
    end
  end
end
