defmodule CyberWeb.BankAccountController do
  use CyberWeb, :controller

  alias CyberCore.Bank
  alias CyberCore.Bank.BankAccount

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък с банкови сметки за текущия tenant.
  Поддържа филтриране по is_active и currency.

  ## Примери

      GET /api/bank_accounts
      GET /api/bank_accounts?is_active=true
      GET /api/bank_accounts?currency=BGN
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    bank_accounts = Bank.list_bank_accounts(tenant_id, opts)
    render(conn, :index, bank_accounts: bank_accounts)
  end

  @doc """
  Създаване на нова банкова сметка.

  ## Примери

      POST /api/bank_accounts
      {
        "bank_account": {
          "account_no": "1234567890",
          "iban": "BG80BNBG96611020345678",
          "bank_name": "Уникредит Булбанк",
          "currency": "BGN",
          "initial_balance": "10000.00",
          "current_balance": "10000.00"
        }
      }
  """
  def create(conn, %{"bank_account" => account_params}) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.put(account_params, "tenant_id", tenant_id)

    with {:ok, %BankAccount{} = account} <- Bank.create_bank_account(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/bank_accounts/#{account}")
      |> render(:show, bank_account: account)
    end
  end

  @doc """
  Извличане на една банкова сметка по ID.
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    bank_account = Bank.get_bank_account!(tenant_id, id)
    render(conn, :show, bank_account: bank_account)
  end

  @doc """
  Актуализиране на банкова сметка.
  ВНИМАНИЕ: current_balance не трябва да се актуализира директно!
  Използвайте банкови транзакции за промяна на баланса.
  """
  def update(conn, %{"id" => id, "bank_account" => account_params}) do
    tenant_id = conn.assigns.tenant_id
    bank_account = Bank.get_bank_account!(tenant_id, id)

    # Премахваме current_balance от параметрите за безопасност
    safe_params = Map.delete(account_params, "current_balance")

    with {:ok, %BankAccount{} = account} <- Bank.update_bank_account(bank_account, safe_params) do
      render(conn, :show, bank_account: account)
    end
  end

  @doc """
  Изтриване на банкова сметка.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    bank_account = Bank.get_bank_account!(tenant_id, id)

    with {:ok, %BankAccount{}} <- Bank.delete_bank_account(bank_account) do
      send_resp(conn, :no_content, "")
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:is_active, params["is_active"])
    |> maybe_add_filter(:currency, params["currency"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, :is_active, value) when value in ["true", "false"] do
    [{:is_active, value == "true"} | opts]
  end

  defp maybe_add_filter(opts, :currency, value) do
    [{:currency, value} | opts]
  end

  defp maybe_add_filter(opts, _key, _value), do: opts
end
