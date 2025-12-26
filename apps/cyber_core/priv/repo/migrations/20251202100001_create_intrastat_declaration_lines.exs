defmodule CyberCore.Repo.Migrations.CreateIntrastatDeclarationLines do
  use Ecto.Migration

  def change do
    create table(:intrastat_declaration_lines) do
      add :commodity_code, :string, null: false
      add :partner_member_state, :string, null: false
      add :country_of_origin, :string
      add :transaction_nature, :string, null: false
      add :delivery_terms, :string
      add :mode_of_transport, :string
      add :net_mass, :decimal
      add :supplementary_unit, :decimal
      add :invoiced_value, :decimal, null: false
      add :statistical_value, :decimal
      add :intrastat_declaration_id, references(:intrastat_declarations, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:intrastat_declaration_lines, [:intrastat_declaration_id])
  end
end
