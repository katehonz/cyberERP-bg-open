defmodule CyberCore.Repo.Migrations.CreateCurrencies do
  use Ecto.Migration

  def change do
    create table(:currencies) do
      add :code, :string, size: 3, null: false
      add :name, :string, size: 100, null: false
      add :name_bg, :string, size: 100, null: false
      add :symbol, :string, size: 10
      add :decimal_places, :integer, default: 2, null: false
      add :is_active, :boolean, default: true, null: false
      add :is_base_currency, :boolean, default: false, null: false
      add :bnb_code, :string, size: 3

      timestamps()
    end

    create unique_index(:currencies, [:code])
    create index(:currencies, [:is_active])
    create index(:currencies, [:is_base_currency])

    # Seed основни валути
    execute """
            INSERT INTO currencies (code, name, name_bg, symbol, is_base_currency, bnb_code, inserted_at, updated_at)
            VALUES
              ('BGN', 'Bulgarian Lev', 'Български лев', 'лв.', TRUE, NULL, NOW(), NOW()),
              ('EUR', 'Euro', 'Евро', '€', FALSE, 'EUR', NOW(), NOW()),
              ('USD', 'US Dollar', 'Американски долар', '$', FALSE, 'USD', NOW(), NOW()),
              ('GBP', 'British Pound', 'Британска лира', '£', FALSE, 'GBP', NOW(), NOW()),
              ('CHF', 'Swiss Franc', 'Швейцарски франк', 'Fr.', FALSE, 'CHF', NOW(), NOW());
            """,
            ""
  end
end
