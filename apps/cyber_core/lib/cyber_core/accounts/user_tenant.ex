defmodule CyberCore.Accounts.UserTenant do
  @moduledoc """
  Релация потребител-фирма с права за достъп.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.{User, Tenant}

  @roles ~w(admin manager user observer)

  schema "user_tenants" do
    belongs_to :user, User
    belongs_to :tenant, Tenant

    field :role, :string, default: "user"
    field :is_active, :boolean, default: true

    timestamps()
  end

  def changeset(user_tenant, attrs) do
    user_tenant
    |> cast(attrs, [:user_id, :tenant_id, :role, :is_active])
    |> validate_required([:user_id, :tenant_id, :role])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :tenant_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:tenant_id)
  end
end
