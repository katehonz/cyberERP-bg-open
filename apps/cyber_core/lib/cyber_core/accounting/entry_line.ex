defmodule CyberCore.Accounting.EntryLine do
  @moduledoc """
  Ред в счетоводен запис.

  Поддържа валутни операции с автоматично изчисляване на base_amount.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Decimal, as: D

  schema "entry_lines" do
    field :tenant_id, :integer
    belongs_to :journal_entry, CyberCore.Accounting.JournalEntry
    belongs_to :account, CyberCore.Accounting.Account
    belongs_to :contact, CyberCore.Contacts.Contact, foreign_key: :contact_id

    field :debit_amount, :decimal, default: D.new(0)
    field :credit_amount, :decimal, default: D.new(0)

    # Валутна поддръжка
    field :currency_code, :string, default: "BGN"
    field :currency_amount, :decimal
    field :exchange_rate, :decimal, default: D.new(1)
    field :base_amount, :decimal, default: D.new(0)

    # ДДС
    field :vat_amount, :decimal, default: D.new(0)
    field :vat_rate_id, :integer

    # Количества
    field :quantity, :decimal
    field :unit_of_measure_code, :string

    field :description, :string
    field :line_order, :integer, default: 1
    field :reference_id, :integer # New field

    timestamps()
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :tenant_id,
      :journal_entry_id,
      :account_id,
      :contact_id,
      :debit_amount,
      :credit_amount,
      :currency_code,
      :currency_amount,
      :exchange_rate,
      :vat_amount,
      :vat_rate_id,
      :quantity,
      :unit_of_measure_code,
      :description,
      :line_order,
      :reference_id # New field
    ])
    |> validate_required([:tenant_id, :account_id])
    |> foreign_key_constraint(:journal_entry_id)
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:contact_id)
    |> validate_debit_or_credit()
    |> calculate_base_amount()
  end

  defp validate_debit_or_credit(changeset) do
    debit = get_field(changeset, :debit_amount) || D.new(0)
    credit = get_field(changeset, :credit_amount) || D.new(0)

    cond do
      D.gt?(debit, 0) and D.equal?(credit, 0) -> changeset
      D.equal?(debit, 0) and D.gt?(credit, 0) -> changeset
      true -> add_error(changeset, :base, "Редът трябва да е или дебит, или кредит")
    end
  end

  defp calculate_base_amount(changeset) do
    currency_code = get_field(changeset, :currency_code)

    if currency_code == "BGN" or is_nil(currency_code) do
      debit = get_field(changeset, :debit_amount) || D.new(0)
      credit = get_field(changeset, :credit_amount) || D.new(0)
      base = if D.gt?(debit, 0), do: debit, else: credit
      put_change(changeset, :base_amount, base)
    else
      currency_amount = get_field(changeset, :currency_amount)
      exchange_rate = get_field(changeset, :exchange_rate) || D.new(1)

      if currency_amount do
        base = D.mult(currency_amount, exchange_rate)

        changeset
        |> put_change(:base_amount, base)
      else
        changeset
      end
    end
  end
end
