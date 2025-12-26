defmodule CyberCore.Repo.Migrations.AddPaymentMethodToExtractedInvoices do
  use Ecto.Migration

  def change do
    alter table(:extracted_invoices) do
      add :payment_method, :string, default: "bank"
    end
  end
end
