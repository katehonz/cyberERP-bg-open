defmodule CyberCore.SAFT.Nomenclature.Nc8Taric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "saft_nc8_taric_codes" do
    field :tenant_id, :integer
    field :code, :string
    field :description_bg, :string
    field :year, :integer, default: 2026
    field :primary_unit, :string
    field :secondary_unit, :string

    timestamps()
  end

  def changeset(nc8_taric, attrs) do
    nc8_taric
    |> cast(attrs, [:tenant_id, :code, :description_bg, :year, :primary_unit, :secondary_unit])
    |> validate_required([:tenant_id, :code, :description_bg, :year])
    |> unique_constraint([:tenant_id, :code, :year])
  end
end
