defmodule CyberCore.Repo.Migrations.AddVatAndOssFieldsToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      # Основание за неначисляване на ДДС (при 0% ставка)
      add :vat_reason, :string

      # OSS режим полета
      # Държава членка на потребление (код като "DE", "FR")
      add :oss_country, :string
      # ДДС ставка в OSS държавата
      add :oss_vat_rate, :decimal, precision: 5, scale: 2
    end

    create index(:invoices, [:oss_country])
  end
end
