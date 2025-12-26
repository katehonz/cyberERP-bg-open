defmodule CyberWeb.Accounting.AccountController do
  use CyberWeb, :controller

  alias CyberCore.Accounting
  alias CyberCore.Accounting.Account

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, _params) do
    tenant = conn.assigns.current_tenant
    accounts = Accounting.list_accounts(tenant.id)
    json(conn, %{data: Enum.map(accounts, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      account = Accounting.get_account!(tenant.id, id)
      json(conn, %{data: serialize(account)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %Account{} = account} <- Accounting.create_account(tenant.id, attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(account)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Account{} = account <- Accounting.get_account!(tenant.id, id),
         {:ok, %Account{} = updated} <-
           Accounting.update_account(tenant.id, account, params |> payload()) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Account{} = account <- Accounting.get_account!(tenant.id, id),
         {:ok, _account} <- Accounting.delete_account(account) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("account", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp serialize(%Account{} = account) do
    %{
      id: account.id,
      code: account.code,
      name: account.name,
      account_type: account.account_type,
      account_class: account.account_class,
      is_active: account.is_active,
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
