defmodule CyberCore.Guardian do
  @moduledoc """
  The Guardian context, for managing roles and permissions.
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo

  alias CyberCore.Guardian.Permission
  alias CyberCore.Guardian.RolePermission
  alias CyberCore.Accounts.User
  alias CyberCore.Accounts.UserTenant

  @doc """
  Returns the list of permissions.

  ## Examples

      iex> list_permissions()
      [%Permission{}, ...]

  """
  def list_permissions do
    Repo.all(Permission)
  end

  @doc """
  Gets a single permission by its name.

  ## Examples

      iex> get_permission_by_name("invoices.create")
      %Permission{}

      iex> get_permission_by_name("nonexistent")
      nil

  """
  def get_permission_by_name(name) do
    Repo.get_by(Permission, name: name)
  end

  @doc """
  Creates a permission.

  ## Examples

      iex> create_permission(%{name: "invoices.create", description: "Create invoices"})
      {:ok, %Permission{}}

      iex> create_permission(%{name: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_permission(attrs \\ %{}) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Grants a permission to a role.

  ## Examples

      iex> grant("admin", "invoices.create")
      {:ok, %RolePermission{}}

  """
  def grant(role, permission_name) do
    with %Permission{} = permission <- get_permission_by_name(permission_name) do
      %RolePermission{}
      |> RolePermission.changeset(%{role: role, permission_id: permission.id})
      |> Repo.insert()
    end
  end

  @doc """
  Revokes a permission from a role.

  ## Examples

      iex> revoke("admin", "invoices.create")
      {:ok, %RolePermission{}}

  """
  def revoke(role, permission_name) do
    with %Permission{} = permission <- get_permission_by_name(permission_name),
         %RolePermission{} = role_permission <-
           Repo.get_by(RolePermission, role: role, permission_id: permission.id) do
      Repo.delete(role_permission)
    end
  end

  @doc """
  Gets all permissions for a role.

  ## Examples

      iex> get_role_permissions("admin")
      ["invoices.create", "invoices.read"]

  """
  def get_role_permissions(role) do
    query =
      from rp in RolePermission,
        where: rp.role == ^role,
        join: p in Permission,
        on: rp.permission_id == p.id,
        select: p.name

    Repo.all(query)
  end

  @doc """
  Checks if a user has a specific permission within a tenant.

  Returns `true` if the user is a superadmin or has the permission for the given tenant.

  ## Examples

      iex> user = %User{role: "user"}
      iex> tenant_id = 1
      iex> permission_name = "invoices.read"
      iex> can?(user, tenant_id, permission_name)
      true

  """
  def can?(%User{} = user, tenant_id, permission_name) do
    if is_superadmin?(user) do
      true
    else
      user_tenant = Repo.get_by(UserTenant, user_id: user.id, tenant_id: tenant_id)

      if user_tenant do
        role_has_permission?(user_tenant.role, permission_name)
      else
        false
      end
    end
  end

  @doc """
  Checks if a user is a superadmin.

  ## Examples

      iex> user = %User{role: "superadmin"}
      iex> is_superadmin?(user)
      true

  """
  def is_superadmin?(%User{role: "superadmin"}), do: true
  def is_superadmin?(_user), do: false

  defp role_has_permission?(role, permission_name) do
    query =
      from rp in RolePermission,
        where: rp.role == ^role,
        join: p in Permission,
        on: rp.permission_id == p.id,
        where: p.name == ^permission_name

    Repo.exists?(query)
  end
end
