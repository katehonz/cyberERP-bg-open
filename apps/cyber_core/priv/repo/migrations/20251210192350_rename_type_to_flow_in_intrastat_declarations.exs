defmodule CyberCore.Repo.Migrations.RenameTypeToFlowInIntrastatDeclarations do
  use Ecto.Migration

  def change do
    rename table(:intrastat_declarations), :type, to: :flow

    alter table(:intrastat_declarations) do
      remove :status
    end
  end
end