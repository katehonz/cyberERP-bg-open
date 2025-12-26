defmodule CyberWeb.Plugs.Authenticate do
  @moduledoc """
  Чете `Authorization: Bearer <token>` хедъра и ако е валиден, присвоява `:current_user`.
  """

  import Plug.Conn
  alias CyberWeb.AuthTokens
  alias CyberCore.Accounts.User

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, %{user: %User{} = user, tenant: tenant}} <- AuthTokens.verify(token),
         true <- tenant_matches?(conn, tenant.id) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_tenant, tenant)
    else
      _ -> conn
    end
  end

  defp tenant_matches?(%{assigns: %{current_tenant: %{id: id}}}, id), do: true
  defp tenant_matches?(%{assigns: %{current_tenant: _}}, _), do: false
  defp tenant_matches?(_conn, _tenant_id), do: true
end
