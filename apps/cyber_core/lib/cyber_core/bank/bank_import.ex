defmodule CyberCore.Bank.BankImport do
  @moduledoc """
  Запис за банков импорт.

  Поддържа:
  - Автоматичен импорт от Salt Edge (saltedge_auto)
  - Ръчен импорт от Salt Edge (saltedge_manual)
  - Импорт от файл (file_upload)
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_imports" do
    field :import_type, :string
    field :file_name, :string
    field :import_format, :string
    field :imported_at, :utc_datetime
    field :transactions_count, :integer, default: 0
    field :total_credit, :decimal, default: Decimal.new(0)
    field :total_debit, :decimal, default: Decimal.new(0)
    field :created_journal_entries, :integer, default: 0
    field :journal_entry_ids, {:array, :integer}, default: []
    field :status, :string, default: "in_progress"
    field :error_message, :string
    field :period_from, :date
    field :period_to, :date
    field :saltedge_attempt_id, :string

    # Associations
    belongs_to :tenant, CyberCore.Accounts.Tenant
    belongs_to :bank_profile, CyberCore.Bank.BankProfile
    belongs_to :created_by, CyberCore.Accounts.User

    has_many :bank_transactions, CyberCore.Bank.BankTransaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bank_import, attrs) do
    bank_import
    |> cast(attrs, [
      :tenant_id,
      :bank_profile_id,
      :import_type,
      :file_name,
      :import_format,
      :imported_at,
      :transactions_count,
      :total_credit,
      :total_debit,
      :created_journal_entries,
      :journal_entry_ids,
      :status,
      :error_message,
      :period_from,
      :period_to,
      :saltedge_attempt_id,
      :created_by_id
    ])
    |> validate_required([
      :tenant_id,
      :bank_profile_id,
      :import_type,
      :imported_at,
      :status
    ])
    |> validate_inclusion(:import_type, ["saltedge_auto", "saltedge_manual", "file_upload"])
    |> validate_inclusion(:status, ["in_progress", "completed", "failed"])
  end

  @doc """
  Маркира импорта като завършен.
  """
  def mark_completed(import, stats) do
    import
    |> changeset(%{
      status: "completed",
      transactions_count: stats.transactions_count,
      total_credit: stats.total_credit,
      total_debit: stats.total_debit,
      created_journal_entries: stats.created_journal_entries,
      journal_entry_ids: stats.journal_entry_ids
    })
  end

  @doc """
  Маркира импорта като неуспешен.
  """
  def mark_failed(import, error_message) do
    import
    |> changeset(%{
      status: "failed",
      error_message: error_message
    })
  end
end
