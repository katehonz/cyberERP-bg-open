defmodule CyberCore.Repo.Migrations.CreateSaftNomenclatures do
  use Ecto.Migration

  def change do
    # 1. IBAN формати по държави (ISO 13616-1997)
    create table(:saft_iban_formats) do
      add :country, :string, null: false
      add :country_code, :string, size: 2, null: false
      add :char_count, :integer, null: false
      add :bank_code_format, :string
      add :iban_fields, :text
      add :comments, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_iban_formats, [:country_code])

    # 2. Видове фактури/документи (Nom_Invoice_Types)
    create table(:saft_invoice_types) do
      add :code, :string, size: 2, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_invoice_types, [:code])

    # 3. Механизми за плащане (Nom_PaymentMethod)
    create table(:saft_payment_methods) do
      add :payment_method_code, :string, size: 2, null: false
      add :payment_mechanism_code, :string, size: 2, null: false
      add :description_bg, :string, null: false
      add :description_en, :string

      timestamps(type: :utc_datetime)
    end

    create index(:saft_payment_methods, [:payment_method_code])
    create index(:saft_payment_methods, [:payment_mechanism_code])
    create unique_index(:saft_payment_methods, [:payment_method_code, :payment_mechanism_code])

    # 4. Видове движение на стоки (Stock_movements)
    create table(:saft_movement_types) do
      add :code, :string, size: 3, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :category, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_movement_types, [:code])

    # 5. Видове движение на активи (AssetMovementTypes)
    create table(:saft_asset_movement_types) do
      add :code, :string, size: 3, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_asset_movement_types, [:code])

    # 6. ДДС режими (VAT_TaxType)
    create table(:saft_vat_tax_types) do
      add :code, :string, size: 10, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_vat_tax_types, [:code])

    # 7. Видове материални запаси (Nom_Inventory_Types)
    create table(:saft_inventory_types) do
      add :code, :string, size: 2, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_inventory_types, [:code])

    # 8. Данъчни кодове (TAX-IMP)
    create table(:saft_tax_codes) do
      add :code, :string, size: 10, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      add :tax_type, :string
      add :rate, :decimal, precision: 5, scale: 2
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_tax_codes, [:code])

    # 9. ISO Държави (ISO3166-1-CountryCodes)
    create table(:saft_countries) do
      add :code, :string, size: 2, null: false
      add :code3, :string, size: 3
      add :numeric_code, :string, size: 3
      add :name_bg, :string, null: false
      add :name_en, :string, null: false
      add :name_official, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_countries, [:code])
    create unique_index(:saft_countries, [:code3])

    # 10. ISO Валути (ISO4217CurrCodes)
    create table(:saft_currencies) do
      add :code, :string, size: 3, null: false
      add :numeric_code, :string, size: 3
      add :name_bg, :string, null: false
      add :name_en, :string, null: false
      add :symbol, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_currencies, [:code])

    # 11. Области в България (ISO3166-2BG - Area Codes)
    create table(:saft_bg_regions) do
      # BG-01 до BG-28
      add :code, :string, size: 5, null: false
      add :name_bg, :string, null: false
      add :name_en, :string
      # област, столица и т.н.
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saft_bg_regions, [:code])

    # 12. Счетоводни сметки НАП (NRA_Nom_Accounts) - ако трябва да се използва
    # Засега пропускаме, защото имаме собствен сметкоплан
  end
end
