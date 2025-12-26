defmodule CyberCore.Accounting.JournalLine do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.{Account, JournalEntry}
  alias CyberCore.Accounts.Tenant
  alias Decimal

  schema "journal_lines" do
    belongs_to :tenant, Tenant
    belongs_to :journal_entry, JournalEntry
    belongs_to :account, Account

    field :description, :string
    field :debit, :decimal, default: Decimal.new(0)
    field :credit, :decimal, default: Decimal.new(0)
    field :currency, :string

    timestamps()
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :tenant_id,
      :journal_entry_id,
      :account_id,
      :description,
      :debit,
      :credit,
      :currency
    ])
    |> validate_required([:tenant_id, :journal_entry_id, :account_id, :currency])
    |> validate_money(:debit)
    |> validate_money(:credit)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:journal_entry_id)
    |> foreign_key_constraint(:account_id)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        is_nil(value) -> []
        Decimal.compare(value, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [{field, "не може да е отрицателна"}]
      end
    end)
  end
end
