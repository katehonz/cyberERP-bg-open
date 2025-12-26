defmodule CyberCore.DocumentProcessing.DocumentUpload do
  @moduledoc """
  Качени документи за обработка с Azure Form Recognizer.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.DocumentProcessing.ExtractedInvoice

  @statuses ~w(pending processing completed failed)
  @document_types ~w(invoice quote receipt purchase_order other)

  schema "document_uploads" do
    field :tenant_id, :integer

    # Storage info
    field :s3_bucket, :string
    field :s3_key, :string
    field :local_path, :string
    field :original_filename, :string
    field :file_size, :integer
    field :file_type, :string

    # Processing status
    field :status, :string, default: "pending"
    field :document_type, :string
    field :processed_at, :utc_datetime
    field :error_message, :string

    # Azure Form Recognizer data
    field :azure_document_id, :string
    field :azure_result, :map

    # Associations
    belongs_to :extracted_invoice, ExtractedInvoice

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document_upload, attrs) do
    document_upload
    |> cast(attrs, [
      :tenant_id,
      :s3_bucket,
      :s3_key,
      :local_path,
      :original_filename,
      :file_size,
      :file_type,
      :status,
      :document_type,
      :processed_at,
      :error_message,
      :azure_document_id,
      :azure_result,
      :extracted_invoice_id
    ])
    |> validate_required([:tenant_id, :original_filename])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:document_type, @document_types,
      message: "must be one of: #{Enum.join(@document_types, ", ")}"
    )
  end

  def valid_statuses, do: @statuses
  def valid_document_types, do: @document_types

  @doc """
  Changeset за маркиране на документ като обработващ се.
  """
  def processing_changeset(document_upload) do
    change(document_upload, %{
      status: "processing",
      error_message: nil,
      updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc """
  Changeset за маркиране на документ като завършен.
  """
  def completed_changeset(document_upload, azure_result) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    change(document_upload, %{
      status: "completed",
      processed_at: now,
      azure_result: azure_result,
      error_message: nil,
      updated_at: now
    })
  end

  @doc """
  Changeset за маркиране на документ като неуспешен.
  """
  def failed_changeset(document_upload, error_message) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    change(document_upload, %{
      status: "failed",
      processed_at: now,
      error_message: error_message,
      updated_at: now
    })
  end
end
