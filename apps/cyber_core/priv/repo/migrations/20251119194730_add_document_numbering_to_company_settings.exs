defmodule CyberCore.Repo.Migrations.AddDocumentNumberingToCompanySettings do
  use Ecto.Migration

  def change do
    alter table(:company_settings) do
      # Номерация за продажби (фактури, ДИ, КИ) - 10 цифри с водеща нула
      add :sales_invoice_next_number, :integer, default: 1

      # Номерация за протоколи ВОП (вътреобщностно придобиване) - 10 цифри с водеща нула
      add :vop_protocol_next_number, :integer, default: 1
    end
  end
end
