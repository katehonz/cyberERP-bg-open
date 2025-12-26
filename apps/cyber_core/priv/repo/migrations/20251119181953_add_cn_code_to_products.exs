defmodule CyberCore.Repo.Migrations.AddCnCodeToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :cn_code_id, references(:cn_nomenclatures, on_delete: :nilify_all)
    end

    create index(:products, [:cn_code_id])
  end
end
