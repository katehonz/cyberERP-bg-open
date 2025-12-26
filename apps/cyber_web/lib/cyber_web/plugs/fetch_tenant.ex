defmodule CyberWeb.Plugs.FetchTenant do
  @moduledoc """
  Извлича текущия tenant на база `x-tenant` header или `tenant`/`tenant_id` параметър.
  """

  import Plug.Conn
  alias CyberCore.Accounts

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn = fetch_query_params(conn)

    case resolve_tenant_identifier(conn) |> fetch_tenant() do
      {:ok, tenant} ->
        assign(conn, :current_tenant, tenant)

      :error ->
        conn
        |> send_resp(:unprocessable_entity, "missing or invalid tenant identifier")
        |> halt()
    end
  end

  defp resolve_tenant_identifier(conn) do
    header_tenant = conn |> get_req_header("x-tenant") |> List.first()

    cond do
      is_binary(header_tenant) and header_tenant != "" -> {:slug, header_tenant}
      conn.params["tenant_id"] -> {:id, conn.params["tenant_id"]}
      conn.params["tenant"] -> {:slug, conn.params["tenant"]}
      true -> :none
    end
  end

  defp fetch_tenant({:slug, slug}) do
    case Accounts.get_tenant_by_slug(slug) do
      %{} = tenant -> {:ok, tenant}
      _ -> :error
    end
  end

  defp fetch_tenant({:id, id}) do
    with {tenant_id, _} <- Integer.parse(to_string(id)),
         tenant when not is_nil(tenant) <- Accounts.get_tenant(tenant_id) do
      {:ok, tenant}
    else
      _ -> :error
    end
  end

  defp fetch_tenant(:none), do: :error
end
