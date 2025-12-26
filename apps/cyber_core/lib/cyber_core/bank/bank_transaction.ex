defmodule CyberCore.Bank.BankTransaction do
  @moduledoc """
  Банкова транзакция (временно хранилище преди създаване на дневен запис).

  Съхранява данни от импортирани транзакции преди тяхното обработване
  и превръщане в счетоводни записи.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_transactions" do
    field :booking_date, :date
    field :value_date, :date
    field :amount, :decimal
    field :currency, :string
    field :is_credit, :boolean

    # Description & references
    field :description, :string
    field :reference, :string
    field :transaction_id, :string

    # Counterpart info
    field :counterpart_name, :string
    field :counterpart_iban, :string
    field :counterpart_bic, :string

    # Processing
    field :is_processed, :boolean, default: false
    field :processed_at, :utc_datetime

    # Metadata
    field :metadata, :map

    # Associations
    belongs_to :bank_account, CyberCore.Bank.BankAccount
    belongs_to :bank_import, CyberCore.Bank.BankImport
    belongs_to :bank_profile, CyberCore.Bank.BankProfile
    belongs_to :tenant, CyberCore.Accounts.Tenant
    belongs_to :journal_entry, CyberCore.Accounting.JournalEntry

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bank_transaction, attrs) do
    bank_transaction
    |> cast(attrs, [
      :bank_account_id,
      :bank_import_id,
      :bank_profile_id,
      :tenant_id,
      :booking_date,
      :value_date,
      :amount,
      :currency,
      :is_credit,
      :description,
      :reference,
      :transaction_id,
      :counterpart_name,
      :counterpart_iban,
      :counterpart_bic,
      :journal_entry_id,
      :is_processed,
      :processed_at,
      :metadata
    ])
    |> validate_required([
      :bank_account_id,
      :bank_import_id,
      :bank_profile_id,
      :tenant_id,
      :booking_date,
      :amount,
      :currency,
      :is_credit
    ])
    |> validate_length(:currency, is: 3)
    |> unique_constraint([:transaction_id, :bank_profile_id],
      name: :bank_transactions_unique_transaction_idx
    )
  end

  @doc """
  Маркира транзакцията като обработена.
  """
  def mark_processed(transaction, journal_entry_id) do
    transaction
    |> changeset(%{
      is_processed: true,
      processed_at: DateTime.utc_now(),
      journal_entry_id: journal_entry_id
    })
  end
end
