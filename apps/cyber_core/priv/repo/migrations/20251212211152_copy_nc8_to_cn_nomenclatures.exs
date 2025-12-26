defmodule CyberCore.Repo.Migrations.CopyNc8ToCnNomenclatures do
  use Ecto.Migration

  def up do
    # Разширяваме description полето
    alter table(:cn_nomenclatures) do
      modify :description, :text, from: {:string, 500}
    end

    # Копираме данните от saft_nc8_taric_codes към cn_nomenclatures
    execute """
    INSERT INTO cn_nomenclatures (code, description, year, primary_unit, supplementary_unit, is_active, inserted_at, updated_at)
    SELECT
      code,
      description_bg,
      year,
      primary_unit,
      secondary_unit,
      true,
      inserted_at,
      updated_at
    FROM saft_nc8_taric_codes
    WHERE tenant_id = 1
    ON CONFLICT (code, year) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM cn_nomenclatures WHERE year = 2026"

    alter table(:cn_nomenclatures) do
      modify :description, :string, from: :text
    end
  end
end
