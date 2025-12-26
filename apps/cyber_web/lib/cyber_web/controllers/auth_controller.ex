defmodule CyberWeb.AuthController do
  use CyberWeb, :controller

  alias CyberCore.Accounts
  alias CyberCore.Accounts.User
  alias CyberWeb.AuthTokens

  plug CyberWeb.Plugs.RequireAuth when action in [:me]

  def register(conn, params) do
    tenant = conn.assigns.current_tenant
    user_count = Accounts.count_users(tenant.id)

    cond do
      user_count > 0 and not admin?(conn) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Само администратор може да създава потребители"})

      true ->
        attrs =
          params
          |> payload()
          |> Map.put("tenant_id", tenant.id)
          |> ensure_role(user_count)

        with {:ok, %User{} = user} <- Accounts.register_user(attrs) do
          render_auth_response(conn, user, :created)
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: translate_errors(changeset)})
        end
    end
  end

  def login(conn, params) do
    tenant = conn.assigns.current_tenant
    email = params |> payload_field("email")
    password = params |> payload_field("password")

    with {:ok, %User{} = user} <- Accounts.authenticate_user(tenant.id, email, password) do
      render_auth_response(conn, user, :ok)
    else
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Невалидни данни за вход"})
    end
  end

  def me(conn, _params) do
    json(conn, %{data: serialize(conn.assigns.current_user)})
  end

  defp render_auth_response(conn, user, status) do
    token = AuthTokens.sign(user)

    conn
    |> put_status(status)
    |> json(%{token: token, user: serialize(user)})
  end

  defp admin?(conn) do
    match?(%{assigns: %{current_user: %User{role: "admin"}}}, conn)
  end

  defp payload(params) do
    Map.get(params, "user", params)
  end

  defp payload_field(params, field) do
    params
    |> payload()
    |> Map.get(to_string(field))
  end

  defp ensure_role(attrs, 0) do
    Map.put_new(attrs, "role", "admin")
  end

  defp ensure_role(attrs, _count), do: attrs

  defp serialize(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      tenant_id: user.tenant_id,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
