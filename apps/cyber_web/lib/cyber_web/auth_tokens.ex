defmodule CyberWeb.AuthTokens do
  @moduledoc """
  Подпомага подписването и верифицирането на токени за API автентикация.
  """

  alias CyberCore.Accounts
  alias CyberCore.Accounts.{Tenant, User}

  @token_salt "cyber-auth-token"
  @token_max_age 60 * 60 * 24 * 7

  def sign(%User{} = user) do
    Phoenix.Token.sign(CyberWeb.Endpoint, @token_salt, {:user, user.id, user.tenant_id})
  end

  def verify(token) when is_binary(token) do
    with {:ok, {:user, user_id, tenant_id}} <-
           Phoenix.Token.verify(CyberWeb.Endpoint, @token_salt, token, max_age: @token_max_age),
         %Tenant{} = tenant <- Accounts.get_tenant(tenant_id),
         %User{} = user <- Accounts.get_user(tenant.id, user_id) do
      {:ok, %{user: user, tenant: tenant}}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def verify(_), do: {:error, :invalid_token}
end
