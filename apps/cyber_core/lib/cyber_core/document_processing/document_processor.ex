defmodule CyberCore.DocumentProcessing.DocumentProcessor do
  @moduledoc """
  Главен сервиз за обработка на документи с Azure Form Recognizer.

  Координира целия workflow:
  1. Взима файлове от S3
  2. Обединява ги при нужда
  3. Изпраща към Azure Form Recognizer
  4. Парсва резултатите
  5. Създава ExtractedInvoice записи
  """

  require Logger

  alias CyberCore.DocumentProcessing

  alias CyberCore.DocumentProcessing.{
    S3Client,
    PdfMerger,
    AzureFormRecognizer,
    InvoiceExtractor
  }

  @doc """
  Обработва група файлове от S3.

  ## Parameters
  - `tenant_id` - ID на tenant
  - `s3_keys` - списък с S3 ключове на файлове за обработка
  - `opts` - опции

  ## Options
  - `:bucket` - S3 bucket (required)
  - `:invoice_type` - "sales" или "purchase" (default: "purchase")
  - `:merge_pdfs` - дали да обединява PDFs (default: true)
  - `:batch_size` - брой файлове на batch при merge (default: 10)

  ## Returns
  - `{:ok, results}` - списък с резултати
  - `{:error, reason}` - грешка
  """
  def process_files_from_s3(tenant_id, s3_keys, opts \\ []) do
    bucket = Keyword.fetch!(opts, :bucket)
    invoice_type = Keyword.get(opts, :invoice_type, "purchase")
    merge_pdfs = Keyword.get(opts, :merge_pdfs, true)
    batch_size = Keyword.get(opts, :batch_size, 10)

    Logger.info("Processing #{length(s3_keys)} files from S3 bucket #{bucket}")

    with {:ok, downloaded_files} <- download_files_from_s3(bucket, s3_keys),
         {:ok, files_to_process} <- maybe_merge_pdfs(downloaded_files, merge_pdfs, batch_size),
         {:ok, results} <- process_pdf_files(tenant_id, files_to_process, invoice_type, bucket) do
      # Cleanup temporary files
      cleanup_temp_files(downloaded_files)
      if merge_pdfs, do: cleanup_temp_files(files_to_process)

      {:ok, results}
    else
      {:error, reason} = error ->
        Logger.error("File processing failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Обработва един PDF файл.

  ## Parameters
  - `tenant_id` - ID на tenant
  - `pdf_binary` - binary съдържание на PDF
  - `original_filename` - оригинално име на файла
  - `opts` - опции

  ## Options
  - `:s3_bucket` - S3 bucket
  - `:s3_key` - S3 key
  - `:invoice_type` - "sales" или "purchase"

  ## Returns
  - `{:ok, %{document_upload: doc, extracted_invoice: invoice}}` - успех
  - `{:error, reason}` - грешка
  """
  def process_single_pdf(tenant_id, pdf_binary, original_filename, opts \\ []) do
    s3_bucket = Keyword.get(opts, :s3_bucket)
    s3_key = Keyword.get(opts, :s3_key)
    local_path = Keyword.get(opts, :local_path)
    invoice_type = Keyword.get(opts, :invoice_type, "purchase")

    Logger.info("Processing PDF: #{original_filename}")

    # Create document upload record
    {:ok, document_upload} =
      DocumentProcessing.create_document_upload(%{
        tenant_id: tenant_id,
        s3_bucket: s3_bucket,
        s3_key: s3_key,
        local_path: local_path,
        original_filename: original_filename,
        file_size: byte_size(pdf_binary),
        file_type: "application/pdf",
        document_type: "invoice",
        status: "pending"
      })

    # Mark as processing
    {:ok, document_upload} = DocumentProcessing.mark_as_processing(document_upload)

    # Analyze with Azure
    case analyze_with_azure(tenant_id, pdf_binary) do
      {:ok, azure_result} ->
        # Mark as completed
        {:ok, document_upload} =
          DocumentProcessing.mark_as_completed(document_upload, azure_result)

        # Extract invoice data
        case InvoiceExtractor.extract_invoice_data(
               azure_result,
               tenant_id,
               document_upload.id,
               invoice_type
             ) do
          {:ok, attrs} ->
            {:ok, extracted_invoice} = DocumentProcessing.create_extracted_invoice(attrs)

            Logger.info("Successfully processed #{original_filename}")

            {:ok, %{document_upload: document_upload, extracted_invoice: extracted_invoice}}

          {:error, reason} ->
            {:ok, _} =
              DocumentProcessing.mark_as_failed(
                document_upload,
                "Failed to extract invoice data: #{reason}"
              )

            {:error, reason}
        end

      {:error, reason} ->
        {:ok, _} =
          DocumentProcessing.mark_as_failed(document_upload, "Azure analysis failed: #{reason}")

        {:error, reason}
    end
  end

  # Private functions

  defp download_files_from_s3(bucket, s3_keys) do
    results =
      Enum.map(s3_keys, fn key ->
        case S3Client.download_file(bucket, key) do
          {:ok, content} ->
            # Save to temp file
            temp_file = Path.join(System.tmp_dir!(), "#{:erlang.unique_integer([:positive])}.pdf")
            File.write!(temp_file, content)
            {:ok, %{s3_key: key, temp_file: temp_file}}

          {:error, reason} ->
            {:error, "Failed to download #{key}: #{reason}"}
        end
      end)

    # Check if all succeeded
    if Enum.all?(results, fn result -> match?({:ok, _}, result) end) do
      {:ok, Enum.map(results, fn {:ok, data} -> data end)}
    else
      first_error = Enum.find(results, fn result -> match?({:error, _}, result) end)
      first_error
    end
  end

  defp maybe_merge_pdfs(files, false, _batch_size), do: {:ok, Enum.map(files, & &1.temp_file)}

  defp maybe_merge_pdfs(files, true, batch_size) do
    temp_files = Enum.map(files, & &1.temp_file)
    output_dir = System.tmp_dir!()

    case PdfMerger.merge_batches(temp_files, output_dir, batch_size) do
      {:ok, merged_files} ->
        {:ok, merged_files}

      {:error, reason} ->
        {:error, "PDF merge failed: #{reason}"}
    end
  end

  defp process_pdf_files(tenant_id, pdf_files, invoice_type, bucket) do
    results =
      Enum.map(pdf_files, fn file_path ->
        pdf_binary = File.read!(file_path)
        original_filename = Path.basename(file_path)

        process_single_pdf(tenant_id, pdf_binary, original_filename,
          s3_bucket: bucket,
          s3_key: "processed/#{original_filename}",
          invoice_type: invoice_type
        )
      end)

    # Filter successful results
    successful =
      results
      |> Enum.filter(fn result -> match?({:ok, _}, result) end)
      |> Enum.map(fn {:ok, data} -> data end)

    if length(successful) > 0 do
      {:ok, successful}
    else
      {:error, "No files were successfully processed"}
    end
  end

  defp analyze_with_azure(tenant_id, pdf_binary) do
    case AzureFormRecognizer.analyze_invoice_from_binary(tenant_id, pdf_binary) do
      {:ok, operation_url} ->
        Logger.info("Azure analysis started, polling for result...")

        # Poll for result with timeout
        case AzureFormRecognizer.poll_for_result(tenant_id, operation_url,
               max_attempts: 30,
               interval: 2000
             ) do
          {:ok, result} ->
            {:ok, result}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cleanup_temp_files(files) when is_list(files) do
    Enum.each(files, fn
      %{temp_file: file} -> File.rm(file)
      file when is_binary(file) -> File.rm(file)
      _ -> :ok
    end)
  end
end
