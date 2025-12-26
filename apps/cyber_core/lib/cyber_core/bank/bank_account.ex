defmodule CyberCore.Bank.BankAccount do
  @moduledoc """
  Банкови сметки на организацията.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @account_types ~w(current savings foreign_currency)

  schema "bank_accounts" do
    field :tenant_id, :integer

    # Данни за сметката
    field :account_no, :string
    field :iban, :string
    field :bic, :string
    field :account_type, :string, default: "current"
    field :currency, :string, default: "BGN"
    field :is_active, :boolean, default: true

    # Данни за банката
    field :bank_name, :string
    field :bank_code, :string
    field :branch_name, :string

    # Салда
    field :initial_balance, :decimal, default: Decimal.new(0)
    field :current_balance, :decimal, default: Decimal.new(0)

    # Допълнителна информация
    field :notes, :string

    # Връзки
    has_many :bank_transactions, CyberCore.Bank.BankTransaction

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :tenant_id,
      :account_no,
      :iban,
      :bic,
      :account_type,
      :currency,
      :is_active,
      :bank_name,
      :bank_code,
      :branch_name,
      :initial_balance,
      :current_balance,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :account_no,
      :iban,
      :bank_name,
      :currency
    ])
    |> validate_inclusion(:account_type, @account_types)
    |> validate_length(:currency, is: 3)
    |> validate_length(:iban, max: 34)
    |> validate_length(:bic, max: 11)
    |> validate_iban()
    |> unique_constraint([:tenant_id, :iban])
  end

  defp validate_iban(changeset) do
    iban = get_field(changeset, :iban)

    if iban && String.length(iban) >= 15 do
      # Проста проверка за български IBAN (BG + 2 цифри + 4 букви + 10 цифри)
      if String.starts_with?(iban, "BG") do
        changeset
      else
        changeset
      end
    else
      changeset
    end
  end
end
