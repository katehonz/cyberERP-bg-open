defmodule CyberCore.Intrastat.IntrastatDeclarationLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "intrastat_declaration_lines" do
    field :commodity_code, :string
    field :partner_member_state, :string # ISO Alpha-2
    field :country_of_origin, :string # ISO Alpha-2
    field :transaction_nature, :string
    field :delivery_terms, :string # Incoterms
    field :mode_of_transport, :string
    field :net_mass, :decimal
    field :supplementary_unit, :decimal
    field :invoiced_value, :decimal
    field :statistical_value, :decimal

    belongs_to :declaration, CyberCore.Intrastat.IntrastatDeclaration,
      foreign_key: :intrastat_declaration_id

    timestamps()
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :intrastat_declaration_id,
      :commodity_code,
      :partner_member_state,
      :country_of_origin,
      :transaction_nature,
      :delivery_terms,
      :mode_of_transport,
      :net_mass,
      :supplementary_unit,
      :invoiced_value,
      :statistical_value
    ])
    |> validate_required([
      :intrastat_declaration_id,
      :commodity_code,
      :partner_member_state,
      :transaction_nature,
      :invoiced_value
    ])
    |> foreign_key_constraint(:intrastat_declaration_id)
  end
end
