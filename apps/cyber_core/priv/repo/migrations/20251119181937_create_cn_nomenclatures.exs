defmodule CyberCore.Repo.Migrations.CreateCnNomenclatures do
  use Ecto.Migration

  def change do
    create table(:cn_nomenclatures) do
      add :code, :string, null: false
      add :description, :string, null: false
      add :year, :integer, null: false
      add :primary_unit, :string
      add :supplementary_unit, :string
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:cn_nomenclatures, [:code, :year])
    create index(:cn_nomenclatures, [:year])
    create index(:cn_nomenclatures, [:is_active])
  end
end
