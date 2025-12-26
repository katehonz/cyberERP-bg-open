defmodule CyberCore.DocumentProcessing.S3Client do
  @moduledoc """
  S3 клиент за Hetzner Object Storage.

  Поддържа:
  - Списък на файлове в bucket
  - Download на файлове
  - Upload на файлове
  - Изтриване на файлове
  - Генериране на pre-signed URLs
  """

  require Logger

  alias ExAws.S3

  @doc """
  Връща списък с файлове в bucket с даден prefix.

  ## Options
  - `:prefix` - prefix за филтриране (default: "")
  - `:max_keys` - максимален брой резултати (default: 1000)
  """
  def list_files(bucket, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "")
    max_keys = Keyword.get(opts, :max_keys, 1000)

    case S3.list_objects(bucket, prefix: prefix, max_keys: max_keys)
         |> ExAws.request(s3_config()) do
      {:ok, %{body: %{contents: contents}}} ->
        files =
          contents
          |> Enum.map(fn item ->
            %{
              key: item.key,
              size: String.to_integer(item.size),
              last_modified: item.last_modified,
              etag: item.e_tag
            }
          end)

        {:ok, files}

      {:error, reason} ->
        Logger.error("S3 list files failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Download файл от S3.

  Връща binary съдържанието на файла.
  """
  def download_file(bucket, key) do
    case S3.get_object(bucket, key)
         |> ExAws.request(s3_config()) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, reason} ->
        Logger.error("S3 download failed for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Upload файл в S3.
  """
  def upload_file(bucket, key, binary_data, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    case S3.put_object(bucket, key, binary_data, content_type: content_type)
         |> ExAws.request(s3_config()) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("S3 upload failed for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Изтрива файл от S3.
  """
  def delete_file(bucket, key) do
    case S3.delete_object(bucket, key)
         |> ExAws.request(s3_config()) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("S3 delete failed for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Генерира pre-signed URL за временен достъп до файл.

  ## Options
  - `:expires_in` - валидност в секунди (default: 3600)
  """
  def generate_presigned_url(bucket, key, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)

    config = s3_config()

    {:ok, url} = S3.presigned_url(config, :get, bucket, key, expires_in: expires_in)

    url
  end

  @doc """
  Проверява дали файл съществува в S3.
  """
  def file_exists?(bucket, key) do
    case S3.head_object(bucket, key)
         |> ExAws.request(s3_config()) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Копира файл в S3 bucket.
  """
  def copy_file(source_bucket, source_key, dest_bucket, dest_key) do
    source = "#{source_bucket}/#{source_key}"

    case S3.put_object_copy(dest_bucket, dest_key, source, [])
         |> ExAws.request(s3_config()) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "S3 copy failed from #{source} to #{dest_bucket}/#{dest_key}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Премества файл (copy + delete).
  """
  def move_file(source_bucket, source_key, dest_bucket, dest_key) do
    with :ok <- copy_file(source_bucket, source_key, dest_bucket, dest_key),
         :ok <- delete_file(source_bucket, source_key) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Configuration

  defp s3_config do
    config = Application.get_env(:cyber_core, __MODULE__, [])

    [
      access_key_id: Keyword.get(config, :access_key_id),
      secret_access_key: Keyword.get(config, :secret_access_key),
      scheme: Keyword.get(config, :scheme, "https://"),
      host: Keyword.get(config, :host),
      port: Keyword.get(config, :port, 443),
      region: Keyword.get(config, :region, "eu-central")
    ]
  end
end
