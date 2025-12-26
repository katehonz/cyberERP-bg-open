defmodule CyberCore.Intrastat.Declaration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "intrastat_declarations" do
    field :tenant_id, :integer
    field :year, :integer
    field :month, :integer
    field :flow, :string # "arrivals" or "dispatches"
    field :country_of_consignment, :string
    field :country_of_origin, :string
    field :transaction_nature, :string
    field :mode_of_transport, :string
    field :commodity_code, :string
    field :net_mass, :decimal
    field :supplementary_unit, :string
    field :invoiced_amount, :decimal
    field :delivery_terms, :string
    field :region, :string

    timestamps()
  end

  @doc false
  def changeset(declaration, attrs) do
    declaration
    |> cast(attrs, [
      :tenant_id,
      :year,
      :month,
      :flow,
      :country_of_consignment,
      :country_of_origin,
      :transaction_nature,
      :mode_of_transport,
      :commodity_code,
      :net_mass,
      :supplementary_unit,
      :invoiced_amount,
      :delivery_terms,
      :region
    ])
    |> validate_required([
      :tenant_id,
      :year,
      :month,
      :flow,
      :country_of_consignment,
      :transaction_nature,
      :commodity_code,
      :invoiced_amount
    ])
  end
end
