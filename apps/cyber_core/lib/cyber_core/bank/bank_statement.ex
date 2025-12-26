defmodule CyberCore.Bank.BankStatement do
  @moduledoc """
  Банкови извлечения.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft imported reconciled archived)

  schema "bank_statements" do
    field :tenant_id, :integer

    # Връзки
    belongs_to :bank_account, CyberCore.Bank.BankAccount

    # Данни за извлечението
    field :statement_no, :string
    field :status, :string, default: "draft"
    field :statement_date, :date
    field :from_date, :date
    field :to_date, :date

    # Салда
    field :opening_balance, :decimal, default: Decimal.new(0)
    field :closing_balance, :decimal, default: Decimal.new(0)
    field :total_debits, :decimal, default: Decimal.new(0)
    field :total_credits, :decimal, default: Decimal.new(0)

    # Метаданни
    field :file_name, :string
    field :file_format, :string
    field :import_date, :naive_datetime

    # Допълнителна информация
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(statement, attrs) do
    statement
    |> cast(attrs, [
      :tenant_id,
      :bank_account_id,
      :statement_no,
      :status,
      :statement_date,
      :from_date,
      :to_date,
      :opening_balance,
      :closing_balance,
      :total_debits,
      :total_credits,
      :file_name,
      :file_format,
      :import_date,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :bank_account_id,
      :statement_date,
      :from_date,
      :to_date
    ])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:tenant_id, :bank_account_id, :statement_no])
    |> validate_date_range()
  end

  defp validate_date_range(changeset) do
    from_date = get_field(changeset, :from_date)
    to_date = get_field(changeset, :to_date)

    if from_date && to_date && Date.compare(from_date, to_date) == :gt do
      add_error(changeset, :to_date, "трябва да е след началната дата")
    else
      changeset
    end
  end
end
