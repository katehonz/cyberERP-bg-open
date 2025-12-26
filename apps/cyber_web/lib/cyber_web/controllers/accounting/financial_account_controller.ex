defmodule CyberWeb.Accounting.FinancialAccountController do
  use CyberWeb, :controller

  alias CyberCore.Accounting
  alias CyberCore.Accounting.FinancialAccount

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, _params) do
    tenant = conn.assigns.current_tenant
    accounts = Accounting.list_financial_accounts(tenant.id)
    json(conn, %{data: Enum.map(accounts, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      account = Accounting.get_financial_account!(tenant.id, id)
      json(conn, %{data: serialize(account)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %FinancialAccount{} = account} <- Accounting.create_financial_account(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(account)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %FinancialAccount{} = account <- Accounting.get_financial_account!(tenant.id, id),
         {:ok, %FinancialAccount{} = updated} <-
           Accounting.update_financial_account(account, params |> payload()) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %FinancialAccount{} = account <- Accounting.get_financial_account!(tenant.id, id),
         {:ok, _account} <- Accounting.delete_financial_account(account) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("financial_account", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp serialize(%FinancialAccount{} = account) do
    %{
      id: account.id,
      name: account.name,
      kind: account.kind,
      currency: account.currency,
      organization_unit: account.organization_unit,
      account_id: account.account_id,
      is_active: account.is_active,
      metadata: account.metadata,
      inserted_at: account.inserted_at,
      updated_at: account.updated_at
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
