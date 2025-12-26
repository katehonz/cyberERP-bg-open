defmodule CyberCore.Repo.Migrations.AddSaftFieldsToContacts do
  use Ecto.Migration

  def change do
    alter table(:contacts) do
      # SAF-T Identification fields
      # ЕИК/БУЛСТАТ
      add :registration_number, :string
      # ДДС номер (BG...)
      add :vat_number, :string
      # Вид данък (100010 за ДДС)
      add :tax_type, :string

      # SAF-T Address fields (допълнително към съществуващите)
      add :street_name, :string
      add :building_number, :string
      add :postal_code, :string
      add :region, :string
      add :additional_address_detail, :string
      add :building, :string

      # SAF-T Contact person fields
      add :contact_person_title, :string
      add :contact_person_first_name, :string
      add :contact_person_last_name, :string
      add :fax, :string
      add :website, :string

      # SAF-T specific fields
      add :is_supplier, :boolean, default: false
      add :is_customer, :boolean, default: false
      add :self_billing_indicator, :boolean, default: false
      add :related_party, :boolean, default: false
      add :related_party_start_date, :date
      add :related_party_end_date, :date

      # Bank account info
      add :iban_number, :string
      add :bank_account_number, :string
      add :bank_sort_code, :string

      # Accounting balances
      # Счетоводна сметка
      add :accounting_account_id, :string
      add :opening_debit_balance, :decimal, precision: 15, scale: 2
      add :opening_credit_balance, :decimal, precision: 15, scale: 2
      add :closing_debit_balance, :decimal, precision: 15, scale: 2
      add :closing_credit_balance, :decimal, precision: 15, scale: 2

      # Tax verification
      # NRA
      add :tax_authority, :string
      add :tax_verification_date, :date

      # Additional names (for foreign entities)
      # Латинско име
      add :name_latin, :string
      # Кирилско име
      add :name_cyrillic, :string
    end

    create index(:contacts, [:registration_number])
    create index(:contacts, [:vat_number])
    create index(:contacts, [:is_supplier])
    create index(:contacts, [:is_customer])
  end
end
