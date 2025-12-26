defmodule CyberCore.Repo.Migrations.AddIntrastatFieldsToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :is_intrastat_applicable, :boolean, default: false, null: false
      add :intrastat_commodity_code, :string
    end
  end
end
