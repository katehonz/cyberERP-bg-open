defmodule CyberCore.Repo.Migrations.MakeS3FieldsOptionalInDocumentUploads do
  use Ecto.Migration

  def change do
    alter table(:document_uploads) do
      modify :s3_bucket, :string, null: true, from: {:string, null: false}
      modify :s3_key, :string, null: true, from: {:string, null: false}
    end
  end
end
