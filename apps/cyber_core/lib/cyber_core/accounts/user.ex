defmodule CyberCore.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias Bcrypt

  @roles ~w(superadmin admin manager user observer)

  schema "users" do
    belongs_to :tenant, Tenant
    many_to_many :tenants, Tenant, join_through: "user_tenants"

    field :email, :string
    field :hashed_password, :string
    field :first_name, :string
    field :last_name, :string
    field :role, :string, default: "user"

    # Password reset
    field :reset_password_token, :string
    field :reset_password_token_expires_at, :utc_datetime

    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> base_changeset(attrs)
    |> validate_required([:tenant_id, :email, :role])
    |> maybe_hash_password()
  end

  def registration_changeset(user, attrs) do
    user
    |> base_changeset(attrs)
    |> validate_required([:tenant_id, :email, :role, :password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password, message: "паролите трябва да съвпадат")
    |> put_password_hash()
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password, message: "паролите трябва да съвпадат")
    |> put_password_hash()
  end

  @doc """
  Changeset for setting the reset password token.
  """
  def reset_password_token_changeset(user) do
    token = generate_reset_token()
    expires_at = DateTime.utc_now() |> DateTime.add(1, :hour)

    user
    |> cast(%{}, [])
    |> put_change(:reset_password_token, token)
    |> put_change(:reset_password_token_expires_at, DateTime.truncate(expires_at, :second))
  end

  @doc """
  Changeset for resetting the password using a token.
  """
  def reset_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password, message: "паролите трябва да съвпадат")
    |> put_password_hash()
    |> put_change(:reset_password_token, nil)
    |> put_change(:reset_password_token_expires_at, nil)
  end

  defp generate_reset_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp base_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :tenant_id,
      :email,
      :first_name,
      :last_name,
      :role,
      :password,
      :password_confirmation
    ])
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:role, @roles,
      message: "допустими стойности: #{Enum.join(@roles, ", ")}"
    )
    |> unique_constraint(:email, name: :users_tenant_id_email_index)
    |> foreign_key_constraint(:tenant_id)
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) do
    email
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.downcase(value)
    end
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, %{hashed_password: Bcrypt.hash_pwd_salt(password)})
  end

  defp put_password_hash(changeset), do: changeset

  defp maybe_hash_password(changeset) do
    put_password_hash(changeset)
  end
end
