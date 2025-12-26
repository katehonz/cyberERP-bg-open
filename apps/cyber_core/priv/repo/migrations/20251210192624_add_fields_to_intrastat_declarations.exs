defmodule CyberCore.Repo.Migrations.AddFieldsToIntrastatDeclarations do
  use Ecto.Migration

  def change do
    alter table(:intrastat_declarations) do
      add :country_of_consignment, :string, null: false, default: "BG"
      add :country_of_origin, :string
      add :transaction_nature, :string, null: false, default: "11"
      add :mode_of_transport, :string
      add :commodity_code, :string, null: false, default: "00000000"
      add :net_mass, :decimal
      add :supplementary_unit, :string
      add :invoiced_amount, :decimal, null: false, default: 0
      add :delivery_terms, :string
      add :region, :string
    end
  end
end