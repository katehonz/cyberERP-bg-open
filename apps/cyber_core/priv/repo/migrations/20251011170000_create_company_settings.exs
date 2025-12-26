defmodule CyberCore.Repo.Migrations.CreateCompanySettings do
  use Ecto.Migration

  def change do
    create table(:company_settings) do
      add :tenant_id, :integer, null: false, comment: "ID на наемател (мултитенант)"

      # Основна информация за фирмата
      add :company_name, :string, size: 200, null: false, comment: "Наименование на фирмата"
      add :company_name_en, :string, size: 200, comment: "Наименование на английски"

      # Данъчна информация
      add :vat_number, :string, size: 15, null: false, comment: "ДДС номер (напр. BG201956793)"
      add :eik, :string, size: 13, comment: "ЕИК/БУЛСТАТ"
      add :is_vat_registered, :boolean, default: true, comment: "Регистриран по ДДС"
      add :vat_registration_date, :date, comment: "Дата на регистрация по ДДС"

      # Адрес
      add :address, :string, size: 200, comment: "Адрес"
      add :city, :string, size: 50, comment: "Град"
      add :postal_code, :string, size: 10, comment: "Пощенски код"
      add :country, :string, size: 2, default: "BG", comment: "Държава (код ISO)"

      # Контактна информация
      add :phone, :string, size: 50, comment: "Телефон"
      add :email, :string, size: 100, comment: "Имейл"
      add :website, :string, size: 100, comment: "Уебсайт"

      # Банкова информация
      add :bank_name, :string, size: 100, comment: "Име на банка"
      add :bank_bic, :string, size: 11, comment: "BIC/SWIFT код"
      add :bank_iban, :string, size: 34, comment: "IBAN"

      # Правно лице информация
      add :mol_name, :string, size: 100, comment: "МОЛ (име)"
      add :mol_position, :string, size: 100, comment: "МОЛ (длъжност)"
      add :accountant_name, :string, size: 100, comment: "Гл. счетоводител (име)"

      # Допълнителни настройки
      add :default_currency, :string, size: 3, default: "BGN", comment: "Валута по подразбиране"

      add :default_vat_rate, :decimal,
        precision: 5,
        scale: 2,
        default: 20.00,
        comment: "ДДС ставка по подразбиране"

      add :use_multicurrency, :boolean, default: false, comment: "Мултивалутен режим"

      # Настройки за фактури
      add :invoice_prefix, :string, size: 10, comment: "Префикс за фактури"
      add :invoice_next_number, :integer, default: 1, comment: "Следващ номер на фактура"

      # Логотип
      add :logo_url, :string, size: 500, comment: "URL на логотип"

      # Забележки
      add :notes, :text, comment: "Забележки"

      timestamps()
    end

    create unique_index(:company_settings, [:tenant_id])
    create index(:company_settings, [:vat_number])
    create index(:company_settings, [:eik])
  end
end
