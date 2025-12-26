defmodule CyberWeb.SessionController do
  use CyberWeb, :controller

  alias CyberCore.Accounts

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user_by_email(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Добре дошли, #{user.first_name}!")
        |> put_session(:user_id, user.id)
        |> put_session(:tenant_id, user.tenant_id)
        |> redirect(to: "/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Грешен email или парола")
        |> redirect(to: "/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Излязохте от системата")
    |> redirect(to: "/login")
  end
end
