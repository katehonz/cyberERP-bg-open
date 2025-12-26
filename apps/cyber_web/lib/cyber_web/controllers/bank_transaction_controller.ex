defmodule CyberWeb.BankTransactionController do
  use CyberWeb, :controller

  alias CyberCore.Bank
  alias CyberCore.Bank.BankTransaction

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък с банкови транзакции за текущия tenant.
  Поддържа филтриране по bank_account_id, transaction_type, status, is_reconciled, дати и търсене.

  ## Примери

      GET /api/bank_transactions
      GET /api/bank_transactions?bank_account_id=1
      GET /api/bank_transactions?transaction_type=receipt
      GET /api/bank_transactions?status=completed
      GET /api/bank_transactions?is_reconciled=false
      GET /api/bank_transactions?from=2025-01-01&to=2025-12-31
      GET /api/bank_transactions?search=payment
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    bank_transactions = Bank.list_bank_transactions(tenant_id, opts)
    render(conn, :index, bank_transactions: bank_transactions)
  end

  @doc """
  Създаване на нова банкова транзакция.
  ВНИМАНИЕ: Това автоматично актуализира баланса на банковата сметка!

  ## Примери

      POST /api/bank_transactions
      {
        "bank_transaction": {
          "bank_account_id": 1,
          "transaction_type": "receipt",
          "transaction_date": "2025-10-11",
          "amount": "500.00",
          "currency": "BGN",
          "counterparty_name": "Клиент ООД",
          "description": "Плащане по фактура INV-2025-001",
          "status": "completed"
        }
      }
  """
  def create(conn, %{"bank_transaction" => transaction_params}) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.put(transaction_params, "tenant_id", tenant_id)

    with {:ok, %BankTransaction{} = transaction} <- Bank.create_bank_transaction(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/bank_transactions/#{transaction}")
      |> render(:show, bank_transaction: transaction)
    end
  end

  @doc """
  Извличане на една банкова транзакция по ID.
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    bank_transaction = Bank.get_bank_transaction!(tenant_id, id)
    render(conn, :show, bank_transaction: bank_transaction)
  end

  @doc """
  Актуализиране на банкова транзакция.
  ВНИМАНИЕ: Промяната на amount и transaction_type НЕ актуализира баланса автоматично!
  Препоръчително е да изтриете и създадете нова транзакция.
  """
  def update(conn, %{"id" => id, "bank_transaction" => transaction_params}) do
    tenant_id = conn.assigns.tenant_id
    bank_transaction = Bank.get_bank_transaction!(tenant_id, id)

    with {:ok, %BankTransaction{} = transaction} <-
           Bank.update_bank_transaction(bank_transaction, transaction_params) do
      transaction = Bank.get_bank_transaction!(tenant_id, transaction.id)
      render(conn, :show, bank_transaction: transaction)
    end
  end

  @doc """
  Изтриване на банкова транзакция.
  ВНИМАНИЕ: Това НЕ връща баланса назад! Трябва да се обработи ръчно.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    bank_transaction = Bank.get_bank_transaction!(tenant_id, id)

    with {:ok, %BankTransaction{}} <- Bank.delete_bank_transaction(bank_transaction) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Маркиране на транзакция като reconciled (изравнена).

  ## Примери

      POST /api/bank_transactions/:id/reconcile
  """
  def reconcile(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    bank_transaction = Bank.get_bank_transaction!(tenant_id, id)

    with {:ok, %BankTransaction{} = transaction} <- Bank.reconcile_transaction(bank_transaction) do
      render(conn, :show, bank_transaction: transaction)
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:bank_account_id, params["bank_account_id"])
    |> maybe_add_filter(:transaction_type, params["transaction_type"])
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:is_reconciled, params["is_reconciled"])
    |> maybe_add_filter(:from, params["from"])
    |> maybe_add_filter(:to, params["to"])
    |> maybe_add_filter(:search, params["search"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, :bank_account_id, value) do
    case Integer.parse(value) do
      {id, ""} -> [{:bank_account_id, id} | opts]
      _ -> opts
    end
  end

  defp maybe_add_filter(opts, :is_reconciled, value) when value in ["true", "false"] do
    [{:is_reconciled, value == "true"} | opts]
  end

  defp maybe_add_filter(opts, key, value)
       when key in [:transaction_type, :status, :from, :to, :search] do
    [{key, value} | opts]
  end

  defp maybe_add_filter(opts, _key, _value), do: opts
end
