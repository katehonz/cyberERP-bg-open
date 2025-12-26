defmodule CyberCore.Repo.Migrations.AddReferenceIdToEntryLines do
  use Ecto.Migration

  def change do
    alter table(:entry_lines) do
      add :reference_id, :integer
    end
  end
end
