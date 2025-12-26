defmodule CyberCore.Guardian.RolePermission do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Guardian.Permission

  schema "role_permissions" do
    field :role, :string
    belongs_to :permission, Permission

    timestamps()
  end

  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, [:role, :permission_id])
    |> validate_required([:role, :permission_id])
    |> unique_constraint([:role, :permission_id])
  end
end
