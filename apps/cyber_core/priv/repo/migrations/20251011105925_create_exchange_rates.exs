defmodule CyberCore.Repo.Migrations.CreateExchangeRates do
  use Ecto.Migration

  def change do
    create table(:exchange_rates) do
      add :from_currency_id, references(:currencies, on_delete: :restrict), null: false
      add :to_currency_id, references(:currencies, on_delete: :restrict), null: false
      add :rate, :decimal, precision: 15, scale: 6, null: false
      add :reverse_rate, :decimal, precision: 15, scale: 6, null: false
      add :valid_date, :date, null: false
      add :rate_source, :string, size: 10, default: "manual", null: false
      add :bnb_rate_id, :string, size: 50
      add :is_active, :boolean, default: true, null: false
      add :notes, :text

      timestamps()
    end

    create unique_index(:exchange_rates, [:from_currency_id, :to_currency_id, :valid_date],
             name: :exchange_rates_currencies_date_unique
           )

    create index(:exchange_rates, [:valid_date])
    create index(:exchange_rates, [:bnb_rate_id])
    create index(:exchange_rates, [:is_active])
  end
end
