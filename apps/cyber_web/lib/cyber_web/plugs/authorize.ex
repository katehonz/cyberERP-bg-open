defmodule CyberWeb.Plugs.Authorize do
  import Plug.Conn

  alias CyberCore.Guardian

  def init(opts), do: opts

  def call(conn, required_permission) do
    user = conn.assigns.current_user
    tenant = conn.assigns.current_tenant

    if Guardian.can?(user, tenant.id, required_permission) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "You do not have permission to perform this action."})
      |> halt()
    end
  end
end
