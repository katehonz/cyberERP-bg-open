defmodule CyberCore.Accounting.FinancialTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.{FinancialAccount, JournalEntry}
  alias CyberCore.Accounts.Tenant
  alias Decimal

  schema "financial_transactions" do
    belongs_to :tenant, Tenant
    belongs_to :financial_account, FinancialAccount
    belongs_to :journal_entry, JournalEntry

    field :transaction_date, :utc_datetime
    field :reference, :string
    field :direction, :string
    field :amount, :decimal, default: Decimal.new(0)
    field :counterparty, :string
    field :notes, :string

    timestamps()
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :tenant_id,
      :financial_account_id,
      :journal_entry_id,
      :transaction_date,
      :reference,
      :direction,
      :amount,
      :counterparty,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :financial_account_id,
      :transaction_date,
      :direction,
      :amount
    ])
    |> validate_inclusion(:direction, ["in", "out"])
    |> validate_change(:amount, fn :amount, value ->
      cond do
        is_nil(value) -> []
        Decimal.compare(value, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [amount: "не може да е отрицателна"]
      end
    end)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:financial_account_id)
    |> foreign_key_constraint(:journal_entry_id)
  end
end
