defmodule CyberCore.Bank.SaltEdgeClient do
  @moduledoc """
  Salt Edge API клиент.

  Документация: https://docs.saltedge.com/account_information/v5/

  Поддържа:
  - Създаване на customers
  - Създаване на connections
  - Fetch на transactions
  - Webhook обработка
  """

  require Logger

  @base_url "https://www.saltedge.com/api/v5"

  @doc """
  Създава нов customer в Salt Edge.
  """
  def create_customer(tenant_id) do
    body = %{
      data: %{
        identifier: "tenant_#{tenant_id}"
      }
    }

    post("/customers", body)
  end

  @doc """
  Създава connect session URL за свързване на банка.
  """
  def create_connect_session(customer_id, opts \\ []) do
    body = %{
      data: %{
        customer_id: customer_id,
        consent: %{
          scopes: ["account_details", "transactions_details"],
          from_date: opts[:from_date] || Date.add(Date.utc_today(), -90) |> Date.to_iso8601()
        },
        attempt: %{
          return_to: opts[:return_url] || "#{get_base_url()}/bank/saltedge/callback"
        },
        locale: "bg"
      }
    }

    post("/connect_sessions/create", body)
  end

  @doc """
  Reconnect session за възстановяване на връзка.
  """
  def create_reconnect_session(connection_id, opts \\ []) do
    body = %{
      data: %{
        connection_id: connection_id,
        consent: %{
          scopes: ["account_details", "transactions_details"],
          from_date: opts[:from_date] || Date.add(Date.utc_today(), -90) |> Date.to_iso8601()
        },
        attempt: %{
          return_to: opts[:return_url] || "#{get_base_url()}/bank/saltedge/callback"
        },
        locale: "bg"
      }
    }

    post("/connect_sessions/reconnect", body)
  end

  @doc """
  Refresh на connection за синхронизация на нови транзакции.
  """
  def refresh_connection(connection_id, opts \\ []) do
    body = %{
      data: %{
        from_date: opts[:from_date] || Date.add(Date.utc_today(), -30) |> Date.to_iso8601()
      }
    }

    put("/connections/#{connection_id}/refresh", body)
  end

  @doc """
  Списък със всички connections за customer.
  """
  def list_connections(customer_id) do
    get("/connections", customer_id: customer_id)
  end

  @doc """
  Информация за конкретна connection.
  """
  def get_connection(connection_id) do
    get("/connections/#{connection_id}")
  end

  @doc """
  Списък със всички accounts за connection.
  """
  def list_accounts(connection_id) do
    get("/accounts", connection_id: connection_id)
  end

  @doc """
  Списък с транзакции за account.

  ## Options
  - `:from_date` - начална дата (ISO 8601)
  - `:to_date` - крайна дата (ISO 8601)
  """
  def list_transactions(account_id, opts \\ []) do
    params = %{
      account_id: account_id,
      from_date: opts[:from_date] || Date.add(Date.utc_today(), -30) |> Date.to_iso8601()
    }

    params =
      if opts[:to_date] do
        Map.put(params, :to_date, opts[:to_date])
      else
        params
      end

    get("/transactions", params)
  end

  @doc """
  Pending transactions.
  """
  def list_pending_transactions(account_id) do
    get("/transactions/pending", account_id: account_id)
  end

  @doc """
  Валидира webhook signature.
  """
  def validate_webhook_signature(body, signature) do
    expected_signature = compute_signature(body)

    if signature == expected_signature do
      :ok
    else
      {:error, "Invalid webhook signature"}
    end
  end

  # HTTP Helpers

  defp get(path, params \\ %{}) do
    url = build_url(path, params)
    headers = build_headers()

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        Logger.error("Salt Edge API error: #{status} - #{body}")
        {:error, "API error: #{status}"}

      {:error, error} ->
        Logger.error("Salt Edge request failed: #{inspect(error)}")
        {:error, "Request failed"}
    end
  end

  defp post(path, body) do
    url = build_url(path)
    headers = build_headers()
    json_body = Jason.encode!(body)

    case HTTPoison.post(url, json_body, headers) do
      {:ok, %{status_code: status, body: response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status_code: status, body: response_body}} ->
        Logger.error("Salt Edge API error: #{status} - #{response_body}")
        {:error, "API error: #{status}"}

      {:error, error} ->
        Logger.error("Salt Edge request failed: #{inspect(error)}")
        {:error, "Request failed"}
    end
  end

  defp put(path, body) do
    url = build_url(path)
    headers = build_headers()
    json_body = Jason.encode!(body)

    case HTTPoison.put(url, json_body, headers) do
      {:ok, %{status_code: status, body: response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status_code: status, body: response_body}} ->
        Logger.error("Salt Edge API error: #{status} - #{response_body}")
        {:error, "API error: #{status}"}

      {:error, error} ->
        Logger.error("Salt Edge request failed: #{inspect(error)}")
        {:error, "Request failed"}
    end
  end

  defp build_url(path, params \\ %{}) do
    url = @base_url <> path

    if Enum.empty?(params) do
      url
    else
      query = URI.encode_query(params)
      url <> "?" <> query
    end
  end

  defp build_headers do
    app_id = get_app_id()
    secret = get_secret()

    expires_at = DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_unix()
    signature = compute_request_signature(expires_at, secret)

    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"App-id", app_id},
      {"Secret", secret},
      {"Expires-at", to_string(expires_at)},
      {"Signature", signature}
    ]
  end

  defp compute_request_signature(expires_at, secret) do
    data = "#{expires_at}|#{secret}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp compute_signature(body) do
    secret = get_secret()
    :crypto.hash(:sha256, "#{body}#{secret}") |> Base.encode16(case: :lower)
  end

  defp get_app_id do
    Application.get_env(:cyber_core, :salt_edge)[:app_id] ||
      raise "Salt Edge App ID not configured"
  end

  defp get_secret do
    Application.get_env(:cyber_core, :salt_edge)[:secret] ||
      raise "Salt Edge Secret not configured"
  end

  defp get_base_url do
    Application.get_env(:cyber_web, CyberWeb.Endpoint)[:url][:host] || "localhost:4000"
  end
end
