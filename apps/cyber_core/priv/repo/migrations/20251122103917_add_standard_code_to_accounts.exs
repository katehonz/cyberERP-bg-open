defmodule CyberCore.Repo.Migrations.AddStandardCodeToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :standard_code, :string
    end
  end
end
