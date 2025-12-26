defmodule CyberCore.Repo.Migrations.AddPaymentFieldsToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      # "cash", "card", "bank"
      add :payment_method, :string
      add :bank_account_id, references(:bank_accounts, on_delete: :nilify_all)
    end

    create index(:invoices, [:bank_account_id])
  end
end
