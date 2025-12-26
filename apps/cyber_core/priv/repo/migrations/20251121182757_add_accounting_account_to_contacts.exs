defmodule CyberCore.Repo.Migrations.AddAccountingAccountToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :accounting_account_id, references(:accounts, on_delete: :nilify_all)
    end
  end
end
