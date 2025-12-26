defmodule CyberCore.Repo.Migrations.AddPriceListToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      add :price_list_id, references(:price_lists, on_delete: :nilify_all)
    end
  end
end