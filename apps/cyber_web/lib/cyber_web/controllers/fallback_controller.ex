defmodule CyberWeb.FallbackController do
  use CyberWeb, :controller

  alias Ecto.Changeset

  def call(conn, {:error, %Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: translate_errors(changeset)})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "resource not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: reason})
  end

  defp translate_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
