defmodule CyberCore.Repo.Migrations.AddSourceDocumentFieldsToJournalEntries do
  use Ecto.Migration

  def change do
    alter table(:journal_entries) do
      add :source_document_id, :integer
      add :source_document_type, :string
    end
  end
end
