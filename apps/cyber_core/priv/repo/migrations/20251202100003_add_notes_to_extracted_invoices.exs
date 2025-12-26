defmodule CyberCore.Repo.Migrations.AddNotesToExtractedInvoices do
  use Ecto.Migration

  def change do
    alter table(:extracted_invoices) do
      add :notes, :text
    end
  end
end
