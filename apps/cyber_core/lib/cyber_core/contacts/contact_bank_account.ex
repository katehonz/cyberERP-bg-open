defmodule CyberCore.Contacts.ContactBankAccount do
  @moduledoc """
  Банкови сметки на контрагенти (ДОСТАВЧИЦИ), извлечени от фактури за покупки.

  **ВАЖНО**: Използва се САМО за ПОКУПКИ (purchase/supplier invoices)!
  - При покупки: Извличаме банкова сметка на ДОСТАВЧИКА
  - При продажби: НЕ извличаме сметка на клиента (нашите сметки са в bank_accounts)

  Използва се за автоматично матчване на ИЗХОДЯЩИ плащания към доставчици.

  ## Workflow - Покупки

  1. **Извличане от supplier invoice**:
     - Azure извлича vendor_bank_iban от фактурата на доставчика
     - При одобрение запазваме IBAN-а в contact_bank_accounts
     - Ако IBAN-ът вече съществува → увеличаваме times_seen

  2. **Автоматично матчване при плащане**:
     - Импортираме bank_transaction с correspondent_account (кореспондентска сметка)
     - Системата търси този IBAN в contact_bank_accounts
     - Намира контрагента (доставчика) автоматично
     - Предлага неплатени supplier invoices за матчване

  ## Tracking

  - `times_seen`: Колко пъти сме видели тази сметка във фактури
  - `first_seen_at`: Кога за първи път сме я видели
  - `last_seen_at`: Последен път видяна
  - `is_verified`: Дали е потвърдена след успешно плащане
  - `is_primary`: Главна сметка на контрагента

  ## Примери

      # От supplier invoice (покупка) извличаме:
      invoice_type: "purchase"
      vendor_name: "ИНФОРМЕЙТ ЕООД"
      vendor_bank_iban: "BG80BNBG96611020345678"

      → Запазваме като contact_bank_account за този доставчик

      # При импорт на bank_transaction (ИЗХОДЯЩО плащане):
      amount: -1200.00 BGN  (минус = изходящо)
      correspondent_account: "BG80BNBG96611020345678"

      → Намираме contact "ИНФОРМЕЙТ ЕООД" автоматично
      → Предлагаме неплатени supplier invoices за матчване
      → Автоматично reconciliation! ✅

  ## Не се използва за продажби!

      # Sales invoice (продажба) - НЕ извличаме customer_bank_iban
      invoice_type: "sales"
      customer_name: "SOME CLIENT Ltd"
      # customer_bank_iban: НЕ ИЗВЛИЧАМЕ!

      # При получаване на плащане:
      amount: +1500.00 BGN  (плюс = входящо)
      our_account: "BG12BANK..." ← Наша сметка от bank_accounts
      correspondent_account: може да няма или да е различна

      → Матчваме по invoice_number в описанието
      → Матчваме по amount
      → Използваме НАШИТЕ bank_accounts, не contact_bank_accounts!
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.{Tenant, User}
  alias CyberCore.Contacts.Contact

  @type t :: %__MODULE__{
          id: integer(),
          tenant_id: integer(),
          contact_id: integer(),
          iban: String.t() | nil,
          bic: String.t() | nil,
          bank_name: String.t() | nil,
          account_number: String.t() | nil,
          currency: String.t(),
          is_primary: boolean(),
          is_verified: boolean(),
          first_seen_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          times_seen: integer(),
          notes: String.t() | nil,
          created_by_id: integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          contact: Contact.t() | Ecto.Association.NotLoaded.t(),
          created_by: User.t() | Ecto.Association.NotLoaded.t()
        }

  schema "contact_bank_accounts" do
    field :iban, :string
    field :bic, :string
    field :bank_name, :string
    field :account_number, :string
    field :currency, :string, default: "BGN"
    field :is_primary, :boolean, default: false
    field :is_verified, :boolean, default: false
    field :first_seen_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :times_seen, :integer, default: 1
    field :notes, :string

    belongs_to :tenant, Tenant
    belongs_to :contact, Contact
    belongs_to :created_by, User

    timestamps()
  end

  @doc false
  def changeset(bank_account, attrs) do
    bank_account
    |> cast(attrs, [
      :tenant_id,
      :contact_id,
      :iban,
      :bic,
      :bank_name,
      :account_number,
      :currency,
      :is_primary,
      :is_verified,
      :first_seen_at,
      :last_seen_at,
      :times_seen,
      :notes,
      :created_by_id
    ])
    |> validate_required([
      :tenant_id,
      :contact_id,
      :currency
    ])
    |> validate_at_least_one_identifier()
    |> normalize_iban()
    |> validate_iban_format()
    |> validate_number(:times_seen, greater_than_or_equal_to: 1)
    |> validate_length(:iban, min: 15, max: 34)
    |> validate_length(:bic, min: 8, max: 11)
    |> validate_length(:currency, is: 3)
    |> unique_constraint(
      [:tenant_id, :contact_id, :iban],
      name: :contact_bank_accounts_unique_iban,
      message: "This IBAN already exists for this contact"
    )
    |> unique_constraint(
      [:tenant_id, :contact_id, :account_number],
      name: :contact_bank_accounts_unique_account_number,
      message: "This account number already exists for this contact"
    )
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:created_by_id)
    |> set_timestamps()
  end

  defp validate_at_least_one_identifier(changeset) do
    iban = get_field(changeset, :iban)
    account_number = get_field(changeset, :account_number)

    if is_nil(iban) && is_nil(account_number) do
      add_error(changeset, :iban, "Either IBAN or account number must be provided")
    else
      changeset
    end
  end

  defp normalize_iban(changeset) do
    case get_change(changeset, :iban) do
      nil ->
        changeset

      iban ->
        # Remove spaces and convert to uppercase
        normalized =
          iban
          |> String.replace(~r/\s/, "")
          |> String.upcase()

        put_change(changeset, :iban, normalized)
    end
  end

  defp validate_iban_format(changeset) do
    case get_field(changeset, :iban) do
      nil ->
        changeset

      iban ->
        # Basic IBAN validation: 2 letters + 2 digits + up to 30 alphanumeric
        if Regex.match?(~r/^[A-Z]{2}\d{2}[A-Z0-9]+$/, iban) do
          changeset
        else
          add_error(changeset, :iban, "Invalid IBAN format")
        end
    end
  end

  defp set_timestamps(changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset
    |> set_if_nil(:first_seen_at, now)
    |> put_change(:last_seen_at, now)
  end

  defp set_if_nil(changeset, field, value) do
    if get_field(changeset, field) == nil do
      put_change(changeset, field, value)
    else
      changeset
    end
  end
end
