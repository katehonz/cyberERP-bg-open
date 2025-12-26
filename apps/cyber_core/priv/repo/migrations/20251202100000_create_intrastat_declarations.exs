defmodule CyberCore.Repo.Migrations.CreateIntrastatDeclarations do
  use Ecto.Migration

  def change do
    create table(:intrastat_declarations) do
      add :tenant_id, :integer, null: false
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :flow, :string, null: false
      add :country_of_consignment, :string, null: false
      add :country_of_origin, :string
      add :transaction_nature, :string, null: false
      add :mode_of_transport, :string
      add :commodity_code, :string, null: false
      add :net_mass, :decimal
      add :supplementary_unit, :string
      add :invoiced_amount, :decimal, null: false
      add :delivery_terms, :string
      add :region, :string

      timestamps()
    end

    create index(:intrastat_declarations, [:tenant_id])
    create index(:intrastat_declarations, [:year, :month, :flow])
  end
end
