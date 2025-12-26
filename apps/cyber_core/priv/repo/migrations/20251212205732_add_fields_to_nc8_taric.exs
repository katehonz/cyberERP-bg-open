defmodule CyberCore.Repo.Migrations.AddFieldsToNc8Taric do
  use Ecto.Migration

  def change do
    alter table(:saft_nc8_taric_codes) do
      add :year, :integer, null: false, default: 2026
      add :primary_unit, :string
      add :secondary_unit, :string
    end

    # Update unique constraint to include year (allows same code for different years)
    drop unique_index(:saft_nc8_taric_codes, [:tenant_id, :code])
    create unique_index(:saft_nc8_taric_codes, [:tenant_id, :code, :year])
  end
end
