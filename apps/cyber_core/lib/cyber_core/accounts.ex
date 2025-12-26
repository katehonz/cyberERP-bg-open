defmodule CyberCore.Accounts do
  @moduledoc """
  Контекстът отговаря за tenant и user управлението в Cyber ERP.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo
  alias CyberCore.Accounts.{Tenant, User, UserTenant}
  alias Bcrypt

  # -- Tenants --

  def list_tenants do
    Repo.all(from t in Tenant, order_by: [asc: t.inserted_at])
  end

  def get_tenant!(id), do: Repo.get!(Tenant, id)

  def get_tenant(id), do: Repo.get(Tenant, id)

  def get_tenant_by_slug(nil), do: nil

  def get_tenant_by_slug(slug) do
    Repo.get_by(Tenant, slug: String.trim(slug))
  end

  def get_tenant_by_slug!(slug) do
    Repo.get_by!(Tenant, slug: slug)
  end

  def create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end

  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  def delete_tenant(%Tenant{} = tenant), do: Repo.delete(tenant)

  @doc """
  Променя основната валута на tenant.
  Валидира дали е позволена промяната според датата и еврозоната.
  """
  def change_base_currency(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.change_base_currency_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Маркира tenant като влязъл в еврозоната.
  Автоматично сменя основната валута на EUR.
  """
  def enter_eurozone(%Tenant{} = tenant, entry_date \\ Date.utc_today()) do
    attrs = %{
      in_eurozone: true,
      eurozone_entry_date: entry_date,
      base_currency_code: "EUR"
    }

    change_base_currency(tenant, attrs)
  end

  @doc """
  Връща основната валута на tenant.
  """
  def get_base_currency(%Tenant{} = tenant) do
    tenant.base_currency_code
  end

  # -- Users --

  def list_users(tenant_id) do
    Repo.all(from u in User, where: u.tenant_id == ^tenant_id, order_by: [asc: u.inserted_at])
  end

  def count_users(tenant_id) do
    Repo.aggregate(from(u in User, where: u.tenant_id == ^tenant_id), :count)
  end

  def get_user!(tenant_id, id) do
    Repo.get_by!(User, tenant_id: tenant_id, id: id)
  end

  def get_user(tenant_id, id) do
    Repo.get_by(User, tenant_id: tenant_id, id: id)
  end

  def get_user_by_email(_tenant_id, nil), do: nil

  def get_user_by_email(tenant_id, email) do
    normalized = email |> String.trim() |> String.downcase()
    Repo.get_by(User, tenant_id: tenant_id, email: normalized)
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def create_user(attrs), do: register_user(attrs)

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  def authenticate_user(nil, _email, _password), do: {:error, :invalid_tenant}

  def authenticate_user(tenant_id, email, password)
      when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email(tenant_id, email),
         true <- Bcrypt.verify_pass(password, user.hashed_password) do
      {:ok, user}
    else
      _ ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_, _, _), do: {:error, :invalid_credentials}

  @doc """
  Автентикира потребител само по email и парола (без tenant_id).
  Връща потребителя с неговия tenant_id.
  """
  def authenticate_user_by_email(email, password)
      when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email_only(email),
         true <- Bcrypt.verify_pass(password, user.hashed_password) do
      {:ok, user}
    else
      _ ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate_user_by_email(_, _), do: {:error, :invalid_credentials}

  defp get_user_by_email_only(email) do
    Repo.get_by(User, email: email)
  end

  # -- User-Tenant Relations --

  @doc """
  Връща всички фирми (tenants) на потребител с активен достъп.
  """
  def list_user_tenants(user_id) do
    query =
      from ut in UserTenant,
        join: t in Tenant,
        on: ut.tenant_id == t.id,
        where: ut.user_id == ^user_id and ut.is_active == true,
        order_by: [asc: t.name],
        select: %{
          tenant: t,
          role: ut.role,
          user_tenant_id: ut.id
        }

    Repo.all(query)
  end

  @doc """
  Проверява дали потребител има достъп до дадена фирма.
  """
  def user_has_tenant_access?(user_id, tenant_id) do
    query =
      from ut in UserTenant,
        where: ut.user_id == ^user_id and ut.tenant_id == ^tenant_id and ut.is_active == true

    Repo.exists?(query)
  end

  @doc """
  Дава достъп на потребител до фирма.
  """
  def grant_tenant_access(user_id, tenant_id, role \\ "user") do
    %UserTenant{}
    |> UserTenant.changeset(%{
      user_id: user_id,
      tenant_id: tenant_id,
      role: role,
      is_active: true
    })
    |> Repo.insert()
  end

  @doc """
  Премахва достъп на потребител до фирма.
  """
  def revoke_tenant_access(user_id, tenant_id) do
    query =
      from ut in UserTenant,
        where: ut.user_id == ^user_id and ut.tenant_id == ^tenant_id

    case Repo.one(query) do
      nil -> {:error, :not_found}
      user_tenant -> Repo.delete(user_tenant)
    end
  end

  @doc """
  Обновява ролята на потребител в дадена фирма.
  """
  def update_user_tenant_role(user_id, tenant_id, role) do
    query =
      from ut in UserTenant,
        where: ut.user_id == ^user_id and ut.tenant_id == ^tenant_id

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      user_tenant ->
        user_tenant
        |> UserTenant.changeset(%{role: role})
        |> Repo.update()
    end
  end

  # -- Password Reset --

  @doc """
  Генерира токен за възстановяване на парола.
  Връща {:ok, user, token} при успех.
  """
  def generate_password_reset_token(email) when is_binary(email) do
    case get_user_by_email_only(email) do
      nil ->
        {:error, :user_not_found}

      user ->
        changeset = User.reset_password_token_changeset(user)

        case Repo.update(changeset) do
          {:ok, updated_user} ->
            {:ok, updated_user, updated_user.reset_password_token}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Проверява токен за възстановяване на парола.
  Връща {:ok, user} ако токенът е валиден и не е изтекъл.
  """
  def verify_password_reset_token(token) when is_binary(token) do
    query =
      from u in User,
        where: u.reset_password_token == ^token

    case Repo.one(query) do
      nil ->
        {:error, :invalid_token}

      user ->
        if DateTime.compare(user.reset_password_token_expires_at, DateTime.utc_now()) == :gt do
          {:ok, user}
        else
          {:error, :token_expired}
        end
    end
  end

  def verify_password_reset_token(_), do: {:error, :invalid_token}

  @doc """
  Нулира паролата на потребител използвайки токен.
  """
  def reset_password_with_token(token, password, password_confirmation) do
    case verify_password_reset_token(token) do
      {:ok, user} ->
        user
        |> User.reset_password_changeset(%{
          password: password,
          password_confirmation: password_confirmation
        })
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end
end
