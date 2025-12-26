defmodule CyberWeb.Plugs.RequireAuth do
  @moduledoc """
  Гарантира, че текущият потребител е автентикиран. При липса връща 401 JSON.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{assigns: %{current_user: _}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
    |> halt()
  end
end
