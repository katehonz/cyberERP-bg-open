defmodule CyberCore.Repo.Migrations.AddLocalPathToDocumentUploads do
  use Ecto.Migration

  def change do
    alter table(:document_uploads) do
      add :local_path, :string
    end
  end
end
