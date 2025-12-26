defmodule CyberCore.Repo.Migrations.RefactorContactAccounting do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      remove :accounting_account_id
    end

    alter table(:entry_lines) do
      add :contact_id, references(:contacts, on_delete: :nothing)
    end
  end
end
