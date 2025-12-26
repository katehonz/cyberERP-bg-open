defmodule CyberCore.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Accounting.Account

  schema "contacts" do
    belongs_to :tenant, Tenant

    # Basic contact info
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :address, :string
    field :city, :string
    field :country, :string
    field :is_company, :boolean, default: false

    # SAF-T Identification
    # ЕИК/БУЛСТАТ
    field :registration_number, :string
    # ДДС номер
    field :vat_number, :string
    # Вид данък
    field :tax_type, :string

    # SAF-T Address details
    field :street_name, :string
    field :building_number, :string
    field :postal_code, :string
    field :region, :string
    field :additional_address_detail, :string
    field :building, :string

    # SAF-T Contact person
    field :contact_person_title, :string
    field :contact_person_first_name, :string
    field :contact_person_last_name, :string
    field :fax, :string
    field :website, :string

    # SAF-T Classification
    field :is_supplier, :boolean, default: false
    field :is_customer, :boolean, default: false
    field :self_billing_indicator, :boolean, default: false
    field :related_party, :boolean, default: false
    field :related_party_start_date, :date
    field :related_party_end_date, :date

    # Bank account
    field :iban_number, :string
    field :bank_account_number, :string
    field :bank_sort_code, :string

    # Accounting balances
    belongs_to :accounting_account, Account, foreign_key: :accounting_account_id
    field :opening_debit_balance, :decimal
    field :opening_credit_balance, :decimal
    field :closing_debit_balance, :decimal
    field :closing_credit_balance, :decimal

    # Tax info
    field :tax_authority, :string
    field :tax_verification_date, :date

    # Additional names
    field :name_latin, :string
    field :name_cyrillic, :string

    belongs_to :price_list, CyberCore.Sales.PriceList

    timestamps()
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :tenant_id,
      :name,
      :email,
      :phone,
      :company,
      :address,
      :city,
      :country,
      :is_company,
      # SAF-T fields
      :registration_number,
      :vat_number,
      :tax_type,
      :street_name,
      :building_number,
      :postal_code,
      :region,
      :additional_address_detail,
      :building,
      :contact_person_title,
      :contact_person_first_name,
      :contact_person_last_name,
      :fax,
      :website,
      :is_supplier,
      :is_customer,
      :self_billing_indicator,
      :related_party,
      :related_party_start_date,
      :related_party_end_date,
      :iban_number,
      :bank_account_number,
      :bank_sort_code,
      :accounting_account_id,
      :opening_debit_balance,
      :opening_credit_balance,
      :closing_debit_balance,
      :closing_credit_balance,
      :tax_authority,
      :tax_verification_date,
      :name_latin,
      :name_cyrillic,
      :price_list_id
    ])
    |> validate_required([:tenant_id, :name])
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "невалиден email формат")
    |> validate_format(:vat_number, ~r/^[A-Z]{2}[A-Z0-9]+$/, message: "невалиден ДДС номер формат")
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:accounting_account_id)
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) do
    email
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.downcase(value)
    end
  end
end
