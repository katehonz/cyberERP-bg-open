defmodule CyberCore.Accounting.JournalEntry do
  @moduledoc """
  Счетоводен запис с тройна дата система.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "journal_entries" do
    field :tenant_id, :integer
    field :entry_number, :string
    field :document_date, :date
    field :vat_date, :date
    field :accounting_date, :date
    field :document_number, :string
    field :description, :string
    field :total_amount, :decimal
    field :total_vat_amount, :decimal
    field :is_posted, :boolean, default: false
    field :posted_at, :utc_datetime
    field :posted_by_id, :integer
    field :vat_document_type, :string
    field :vat_purchase_operation, :string
    field :vat_sales_operation, :string
    field :vat_additional_operation, :string
    field :vat_additional_data, :string
    field :created_by_id, :integer
    field :source_document_id, :integer
    field :source_document_type, :string

    has_many :lines, CyberCore.Accounting.EntryLine, on_delete: :delete_all

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :tenant_id,
      :entry_number,
      :document_date,
      :vat_date,
      :accounting_date,
      :document_number,
      :description,
      :total_amount,
      :total_vat_amount,
      :is_posted,
      :vat_document_type,
      :vat_purchase_operation,
      :vat_sales_operation,
      :created_by_id,
      :source_document_id,
      :source_document_type
    ])
    |> validate_required([:tenant_id, :document_date, :accounting_date, :description])
    |> unique_constraint([:tenant_id, :entry_number])
    |> cast_assoc(:lines, required: true)
  end
end
