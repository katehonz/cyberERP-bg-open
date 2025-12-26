defmodule CyberCore.Repo.Migrations.CreateSaftNc8TaricCodesTable do
  use Ecto.Migration

  def change do
    create table(:saft_nc8_taric_codes) do
      add :tenant_id, :integer, null: false
      add :code, :string, null: false
      add :description_bg, :string, null: false

      timestamps()
    end

    create unique_index(:saft_nc8_taric_codes, [:tenant_id, :code])
  end
end
