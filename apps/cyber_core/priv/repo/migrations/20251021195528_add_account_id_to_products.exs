defmodule CyberCore.Repo.Migrations.AddAccountIdToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :account_id, references(:accounts, on_delete: :nilify_all)
    end

    create index(:products, [:account_id])
  end
end
