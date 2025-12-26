defmodule CyberCore.Repo.Migrations.AddBaseCurrencyToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      # Основна валута на организацията
      add :base_currency_code, :string, default: "BGN", null: false

      # Дата на която валутата е зададена/променена за последен път
      add :base_currency_changed_at, :utc_datetime

      # Флаг дали сме в еврозоната (от 2026г.)
      add :in_eurozone, :boolean, default: false, null: false

      # Дата на влизане в еврозоната (за валидация)
      add :eurozone_entry_date, :date
    end

    # Добави индекс за по-бързо търсене по валута
    create index(:tenants, [:base_currency_code])
  end
end
