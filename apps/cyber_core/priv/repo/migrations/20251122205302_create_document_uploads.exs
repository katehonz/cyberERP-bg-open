defmodule CyberCore.Repo.Migrations.CreateDocumentUploads do
  use Ecto.Migration

  def change do
    create table(:document_uploads) do
      add :tenant_id, :integer, null: false

      # S3 storage info
      add :s3_bucket, :string, null: false
      add :s3_key, :string, null: false
      add :original_filename, :string, null: false
      add :file_size, :bigint
      add :file_type, :string

      # Processing status
      add :status, :string, null: false, default: "pending"
      add :document_type, :string
      add :processed_at, :utc_datetime
      add :error_message, :text

      # Azure Form Recognizer data
      add :azure_document_id, :string
      add :azure_result, :map

      # Link to extracted invoice (if applicable)
      add :extracted_invoice_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:document_uploads, [:tenant_id])
    create index(:document_uploads, [:status])
    create index(:document_uploads, [:s3_key])
    create index(:document_uploads, [:document_type])
  end
end
