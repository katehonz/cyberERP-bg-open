defmodule CyberCore.Repo.Migrations.CreateSales do
  use Ecto.Migration

  def change do
    create table(:sales) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :invoice_number, :string, null: false
      add :customer_id, references(:contacts, on_delete: :nilify_all)
      add :customer_name, :string, null: false
      add :customer_email, :citext
      add :customer_phone, :string
      add :customer_address, :string
      add :date, :utc_datetime, null: false
      add :amount, :decimal, null: false
      add :status, :string, null: false, default: "pending"
      add :notes, :text

      timestamps()
    end

    create index(:sales, [:tenant_id])
    create unique_index(:sales, [:tenant_id, :invoice_number])
    create index(:sales, [:tenant_id, :date])
    create index(:sales, [:customer_id])
  end
end
