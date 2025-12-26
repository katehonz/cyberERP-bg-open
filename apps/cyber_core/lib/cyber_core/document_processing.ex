defmodule CyberCore.DocumentProcessing do
  @moduledoc """
  Контекст за управление на обработка на документи с Azure Form Recognizer.
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo

  alias CyberCore.DocumentProcessing.{DocumentUpload, ExtractedInvoice}
  alias CyberCore.Purchase
  alias CyberCore.Sales

  ## Document Uploads

  @doc """
  Връща списък с качени документи за tenant.
  """
  def list_document_uploads(tenant_id, opts \\ []) do
    filters = Keyword.get(opts, :filters, %{})
    preloads = Keyword.get(opts, :preloads, [])

    DocumentUpload
    |> where(tenant_id: ^tenant_id)
    |> apply_document_upload_filters(filters)
    |> order_by([d], desc: d.inserted_at)
    |> preload(^preloads)
    |> Repo.all()
  end

  defp apply_document_upload_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query -> where(query, [d], d.status == ^status)
      {:document_type, type}, query -> where(query, [d], d.document_type == ^type)
      _, query -> query
    end)
  end

  @doc """
  Връща документ по ID.
  """
  def get_document_upload!(tenant_id, id, preloads \\ []) do
    DocumentUpload
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  @doc """
  Създава нов document upload.
  """
  def create_document_upload(attrs \\ %{}) do
    %DocumentUpload{}
    |> DocumentUpload.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира document upload.
  """
  def update_document_upload(%DocumentUpload{} = document_upload, attrs) do
    document_upload
    |> DocumentUpload.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Маркира документ като обработващ се.
  """
  def mark_as_processing(%DocumentUpload{} = document_upload) do
    document_upload
    |> DocumentUpload.processing_changeset()
    |> Repo.update()
  end

  @doc """
  Маркира документ като завършен.
  """
  def mark_as_completed(%DocumentUpload{} = document_upload, azure_result) do
    document_upload
    |> DocumentUpload.completed_changeset(azure_result)
    |> Repo.update()
  end

  @doc """
  Маркира документ като неуспешен.
  """
  def mark_as_failed(%DocumentUpload{} = document_upload, error_message) do
    document_upload
    |> DocumentUpload.failed_changeset(error_message)
    |> Repo.update()
  end

  @doc """
  Изтрива document upload.
  """
  def delete_document_upload(%DocumentUpload{} = document_upload) do
    Repo.delete(document_upload)
  end

  ## Extracted Invoices

  @doc """
  Връща списък с извлечени фактури за tenant.
  """
  def list_extracted_invoices(tenant_id, opts \\ []) do
    filters = Keyword.get(opts, :filters, %{})
    preloads = Keyword.get(opts, :preloads, [])

    ExtractedInvoice
    |> where(tenant_id: ^tenant_id)
    |> apply_extracted_invoice_filters(filters)
    |> order_by([e], desc: e.inserted_at)
    |> preload(^preloads)
    |> Repo.all()
  end

  defp apply_extracted_invoice_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query -> where(query, [e], e.status == ^status)
      {:invoice_type, type}, query -> where(query, [e], e.invoice_type == ^type)
      _, query -> query
    end)
  end

  @doc """
  Връща извлечена фактура по ID.
  """
  def get_extracted_invoice!(tenant_id, id, preloads \\ []) do
    ExtractedInvoice
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  @doc """
  Създава нова extracted invoice.
  """
  def create_extracted_invoice(attrs \\ %{}) do
    %ExtractedInvoice{}
    |> ExtractedInvoice.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира extracted invoice.
  """
  def update_extracted_invoice(%ExtractedInvoice{} = extracted_invoice, attrs) do
    extracted_invoice
    |> ExtractedInvoice.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Одобрява извлечена фактура.
  """
  def approve_extracted_invoice(%ExtractedInvoice{} = extracted_invoice, user_id) do
    extracted_invoice
    |> ExtractedInvoice.approve_changeset(user_id)
    |> Repo.update()
  end

  @doc """
  Отменя одобрението на фактура
  """
  def unapprove_invoice(%ExtractedInvoice{} = extracted_invoice) do
    Repo.transaction(fn ->
      # Delete the converted invoice
      case extracted_invoice.converted_invoice_type do
        "supplier_invoice" ->
          invoice = Purchase.get_supplier_invoice!(extracted_invoice.tenant_id, extracted_invoice.converted_invoice_id)
          Repo.delete!(invoice)

        "invoice" ->
          invoice = Sales.get_invoice!(extracted_invoice.tenant_id, extracted_invoice.converted_invoice_id)
          Repo.delete!(invoice)

        _ ->
          :ok
      end

      # Revert the status of the extracted invoice
      extracted_invoice
      |> ExtractedInvoice.changeset(%{
        status: "pending_review",
        converted_invoice_id: nil,
        converted_invoice_type: nil,
        approved_at: nil,
        approved_by_id: nil
      })
      |> Repo.update!()
    end)
  end

  @doc """
  Отхвърля извлечена фактура.
  """
  def reject_extracted_invoice(%ExtractedInvoice{} = extracted_invoice, user_id, reason) do
    extracted_invoice
    |> ExtractedInvoice.reject_changeset(user_id, reason)
    |> Repo.update()
  end

  @doc """
  Маркира извлечената фактура като конвертирана.
  """
  def mark_as_converted(%ExtractedInvoice{} = extracted_invoice, invoice_id, invoice_type) do
    extracted_invoice
    |> ExtractedInvoice.converted_changeset(invoice_id, invoice_type)
    |> Repo.update()
  end

  @doc """
  Изтрива extracted invoice.
  """
  def delete_extracted_invoice(%ExtractedInvoice{} = extracted_invoice) do
    Repo.delete(extracted_invoice)
  end

  @doc """
  Връща changeset за валидация.
  """
  def change_document_upload(%DocumentUpload{} = document_upload, attrs \\ %{}) do
    DocumentUpload.changeset(document_upload, attrs)
  end

  @doc """
  Връща changeset за валидация.
  """
  def change_extracted_invoice(%ExtractedInvoice{} = extracted_invoice, attrs \\ %{}) do
    ExtractedInvoice.changeset(extracted_invoice, attrs)
  end
end

