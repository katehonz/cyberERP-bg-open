defmodule CyberCore.Repo.Migrations.AddOpeningBalancesToProductsAndAccounts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :opening_quantity, :decimal, precision: 15, scale: 2, default: 0
      add :opening_cost, :decimal, precision: 15, scale: 2, default: 0
    end

    alter table(:accounts) do
      add :opening_balance, :decimal, precision: 15, scale: 2, default: 0
    end
  end
end