defmodule CyberWeb.Accounting.FinancialTransactionController do
  use CyberWeb, :controller

  alias CyberCore.Accounting
  alias CyberCore.Accounting.FinancialTransaction

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    filters = build_filters(params)

    transactions = Accounting.list_financial_transactions(tenant.id, filters)
    json(conn, %{data: Enum.map(transactions, &serialize/1)})
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %FinancialTransaction{} = transaction} <-
           Accounting.create_financial_transaction(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(transaction)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %FinancialTransaction{} = transaction <-
           CyberCore.Repo.get_by!(FinancialTransaction, tenant_id: tenant.id, id: id),
         {:ok, %FinancialTransaction{} = updated} <-
           Accounting.update_financial_transaction(transaction, params |> payload()) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %FinancialTransaction{} = transaction <-
           CyberCore.Repo.get_by!(FinancialTransaction, tenant_id: tenant.id, id: id),
         {:ok, _transaction} <- Accounting.delete_financial_transaction(transaction) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("financial_transaction", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp build_filters(params) do
    []
    |> maybe_put(:financial_account_id, params["financial_account_id"])
    |> maybe_put(:direction, params["direction"])
    |> maybe_put(:from, params["from"])
    |> maybe_put(:to, params["to"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp serialize(%FinancialTransaction{} = transaction) do
    %{
      id: transaction.id,
      financial_account_id: transaction.financial_account_id,
      journal_entry_id: transaction.journal_entry_id,
      transaction_date: transaction.transaction_date,
      reference: transaction.reference,
      direction: transaction.direction,
      amount: transaction.amount,
      counterparty: transaction.counterparty,
      notes: transaction.notes,
      inserted_at: transaction.inserted_at,
      updated_at: transaction.updated_at
    }
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: {:error, :not_found}
end
