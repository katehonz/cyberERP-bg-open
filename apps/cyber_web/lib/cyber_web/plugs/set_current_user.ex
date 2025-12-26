defmodule CyberWeb.Plugs.SetCurrentUser do
  import Plug.Conn

  alias CyberCore.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    tenant_id = get_session(conn, :tenant_id)

    cond do
      user_id && tenant_id ->
        user = Accounts.get_user(tenant_id, user_id)
        tenant = Accounts.get_tenant(tenant_id)

        conn
        |> assign(:current_user, user)
        |> assign(:current_tenant, tenant)

      true ->
        conn
    end
  end
end
