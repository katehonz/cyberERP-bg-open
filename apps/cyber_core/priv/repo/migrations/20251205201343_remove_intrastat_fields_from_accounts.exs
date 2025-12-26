defmodule CyberCore.Repo.Migrations.RemoveIntrastatFieldsFromAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      remove :is_intrastat_applicable
      remove :intrastat_commodity_code
    end
  end
end
