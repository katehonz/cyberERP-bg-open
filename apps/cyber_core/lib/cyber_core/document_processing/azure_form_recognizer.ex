defmodule CyberCore.DocumentProcessing.AzureFormRecognizer do
  @moduledoc """
  Azure Form Recognizer API клиент.

  Документация: https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/

  Поддържа:
  - Анализ на фактури (prebuilt-invoice model)
  - Асинхронно извличане на резултати
  - Batch обработка на документи
  """

  require Logger

  @doc """
  Стартира анализ на документ с prebuilt-invoice модел.

  Връща operation location URL за проследяване на статуса.
  """
  def analyze_invoice(tenant_id, document_url) do
    body = %{
      urlSource: document_url
    }

    case post(tenant_id, "/documentintelligence/documentModels/prebuilt-invoice:analyze", body) do
      {:ok, _response, headers} ->
        operation_location = get_operation_location(headers)
        {:ok, operation_location}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Стартира анализ на документ от binary данни.
  """
  def analyze_invoice_from_binary(tenant_id, pdf_binary) do
    case post_binary(
           tenant_id,
           "/documentintelligence/documentModels/prebuilt-invoice:analyze",
           pdf_binary
         ) do
      {:ok, _response, headers} ->
        operation_location = get_operation_location(headers)
        {:ok, operation_location}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Проверява статуса на анализ операция.

  Връща:
  - {:ok, :running} - все още се обработва
  - {:ok, :succeeded, result} - завършен успешно
  - {:error, reason} - грешка
  """
  def get_analyze_result(tenant_id, operation_url) do
    case get(tenant_id, operation_url) do
      {:ok, %{"status" => "running"}} ->
        {:ok, :running}

      {:ok, %{"status" => "notStarted"}} ->
        {:ok, :running}

      {:ok, %{"status" => "succeeded", "analyzeResult" => result}} ->
        {:ok, :succeeded, result}

      {:ok, %{"status" => "failed", "error" => error}} ->
        {:error, "Analysis failed: #{inspect(error)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Polling за резултат с retry механизъм.

  Опции:
  - `:max_attempts` - максимален брой опити (default: 30)
  - `:interval` - интервал между опитите в ms (default: 2000)
  """
  def poll_for_result(tenant_id, operation_url, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 30)
    interval = Keyword.get(opts, :interval, 2000)

    do_poll(tenant_id, operation_url, max_attempts, interval, 0)
  end

  defp do_poll(_tenant_id, _operation_url, max_attempts, _interval, attempt)
       when attempt >= max_attempts do
    {:error, "Polling timeout after #{attempt} attempts"}
  end

  defp do_poll(tenant_id, operation_url, max_attempts, interval, attempt) do
    case get_analyze_result(tenant_id, operation_url) do
      {:ok, :running} ->
        Process.sleep(interval)
        do_poll(tenant_id, operation_url, max_attempts, interval, attempt + 1)

      {:ok, :succeeded, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # HTTP Helpers

  defp get(tenant_id, url) do
    with {:ok, config} <- get_tenant_config(tenant_id) do
      headers = build_headers(config)

      full_url =
        if String.starts_with?(url, "http") do
          url
        else
          build_url(config, url)
        end

      case HTTPoison.get(full_url, headers) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, Jason.decode!(body)}

        {:ok, %{status_code: status, body: body}} ->
          Logger.error("Azure Form Recognizer API error: #{status} - #{body}")
          {:error, "API error: #{status}"}

        {:error, error} ->
          Logger.error("Azure Form Recognizer request failed: #{inspect(error)}")
          {:error, "Request failed"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp post(tenant_id, path, body) do
    with {:ok, config} <- get_tenant_config(tenant_id) do
      url = build_url(config, path)
      headers = build_headers(config)
      json_body = Jason.encode!(body)

      case HTTPoison.post(url, json_body, headers) do
        {:ok, %{status_code: status, body: response_body, headers: response_headers}}
        when status in 200..299 ->
          decoded_body = if response_body == "", do: %{}, else: Jason.decode!(response_body)
          {:ok, decoded_body, response_headers}

        {:ok, %{status_code: status, body: response_body}} ->
          Logger.error("Azure Form Recognizer API error: #{status} - #{response_body}")
          {:error, "API error: #{status}"}

        {:error, error} ->
          Logger.error("Azure Form Recognizer request failed: #{inspect(error)}")
          {:error, "Request failed"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp post_binary(tenant_id, path, binary_data) do
    with {:ok, config} <- get_tenant_config(tenant_id) do
      url = build_url(config, path)
      headers = build_headers(config, "application/pdf")

      case HTTPoison.post(url, binary_data, headers) do
        {:ok, %{status_code: status, body: response_body, headers: response_headers}}
        when status in 200..299 ->
          decoded_body = if response_body == "", do: %{}, else: Jason.decode!(response_body)
          {:ok, decoded_body, response_headers}

        {:ok, %{status_code: status, body: response_body}} ->
          Logger.error("Azure Form Recognizer API error: #{status} - #{response_body}")
          {:error, "API error: #{status}"}

        {:error, error} ->
          Logger.error("Azure Form Recognizer request failed: #{inspect(error)}")
          {:error, "Request failed"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_url(config, path) do
    endpoint = config.endpoint
    api_version = config.api_version

    "#{endpoint}#{path}?api-version=#{api_version}"
  end

  defp build_headers(config, content_type \\ "application/json") do
    api_key = config.api_key

    [
      {"Content-Type", content_type},
      {"Ocp-Apim-Subscription-Key", api_key}
    ]
  end

  defp get_operation_location(headers) do
    Enum.find_value(headers, fn
      {"operation-location", value} -> value
      {"Operation-Location", value} -> value
      _ -> nil
    end)
  end

  defp get_config(key, default \\ nil) do
    # Fallback to Application config if provided
    Application.get_env(:cyber_core, __MODULE__, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Вземане на config от базата данни за конкретен tenant.
  """
  def get_tenant_config(tenant_id) do
    alias CyberCore.Settings

    case Settings.get_integration_setting(tenant_id, "azure_form_recognizer", "default") do
      {:ok, %{config: config}} ->
        endpoint = config["endpoint"]
        api_key = config["api_key"]

        if is_nil(endpoint) or is_nil(api_key) do
          {:error, "Azure Form Recognizer is not configured: endpoint or api_key is missing."}
        else
          {:ok,
           %{
             endpoint: endpoint,
             api_key: api_key,
             api_version: config["api_version"] || "2023-07-31"
           }}
        end

      {:error, :not_found} ->
        # Fallback to application config
        endpoint = get_config(:endpoint)
        api_key = get_config(:api_key)

        if is_nil(endpoint) or is_nil(api_key) do
          {:error,
           "Azure Form Recognizer is not configured: checked database and application config."}
        else
          {:ok,
           %{
             endpoint: endpoint,
             api_key: api_key,
             api_version: get_config(:api_version, "2023-07-31")
           }}
        end
    end
  end
end
