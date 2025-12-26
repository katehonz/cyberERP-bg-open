defmodule CyberCore.DocumentProcessing.ExtractedInvoice do
  @moduledoc """
  Извлечени данни от фактури чрез Azure Form Recognizer.
  Очаква преглед и одобрение преди създаване на финална фактура.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.DocumentProcessing.DocumentUpload
  alias CyberCore.Accounts.User

  @statuses ~w(pending_review approved rejected)
  @invoice_types ~w(sales purchase)

  schema "extracted_invoices" do
    field :tenant_id, :integer

    # Invoice metadata
    field :invoice_type, :string
    field :status, :string, default: "pending_review"
    field :confidence_score, :decimal

    # Extracted invoice fields
    field :invoice_number, :string
    field :invoice_date, :date
    field :due_date, :date

    # Vendor/Customer info
    field :vendor_name, :string
    field :vendor_address, :string
    field :vendor_vat_number, :string
    field :vendor_bank_account, :string
    field :vendor_bank_iban, :string
    field :vendor_bank_bic, :string
    field :vendor_bank_name, :string
    field :customer_name, :string
    field :customer_address, :string
    field :customer_vat_number, :string

    # Financial fields
    field :subtotal, :decimal
    field :tax_amount, :decimal
    field :total_amount, :decimal
    field :currency, :string, default: "BGN"
    field :payment_method, :string, default: "bank"
    field :notes, :string

    # Line items as JSONB array
    field :line_items, {:array, :map}, default: []

    # Raw Azure data
    field :raw_data, :map

    # Approval tracking
    field :approved_at, :utc_datetime
    field :rejection_reason, :string

    # Link to converted invoice
    field :converted_invoice_id, :integer
    field :converted_invoice_type, :string

    # Associations
    belongs_to :document_upload, DocumentUpload
    belongs_to :approved_by, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(extracted_invoice, attrs) do
    extracted_invoice
    |> cast(attrs, [
      :tenant_id,
      :document_upload_id,
      :invoice_type,
      :status,
      :confidence_score,
      :invoice_number,
      :invoice_date,
      :due_date,
      :vendor_name,
      :vendor_address,
      :vendor_vat_number,
      :vendor_bank_account,
      :vendor_bank_iban,
      :vendor_bank_bic,
      :vendor_bank_name,
      :customer_name,
      :customer_address,
      :customer_vat_number,
      :subtotal,
      :tax_amount,
      :total_amount,
      :currency,
      :payment_method,
      :notes,
      :line_items,
      :raw_data,
      :approved_by_id,
      :approved_at,
      :rejection_reason,
      :converted_invoice_id,
      :converted_invoice_type
    ])
    |> validate_required([:tenant_id, :document_upload_id, :invoice_type])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:invoice_type, @invoice_types)
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_financial_fields()
  end

  defp validate_financial_fields(changeset) do
    changeset
    |> validate_number(:subtotal, greater_than_or_equal_to: 0)
    |> validate_number(:tax_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
  end

  def valid_statuses, do: @statuses
  def valid_invoice_types, do: @invoice_types

  @doc """
  Changeset за одобряване на извлечена фактура.
  """
  def approve_changeset(extracted_invoice, user_id) do
    change(extracted_invoice, %{
      status: "approved",
      approved_by_id: user_id,
      approved_at: DateTime.truncate(DateTime.utc_now(), :second),
      rejection_reason: nil
    })
  end

  @doc """
  Changeset за отхвърляне на извлечена фактура.
  """
  def reject_changeset(extracted_invoice, user_id, reason) do
    change(extracted_invoice, %{
      status: "rejected",
      approved_by_id: user_id,
      approved_at: DateTime.truncate(DateTime.utc_now(), :second),
      rejection_reason: reason
    })
  end

  @doc """
  Changeset за маркиране като конвертирана.
  """
  def converted_changeset(extracted_invoice, invoice_id, invoice_type) do
    change(extracted_invoice, %{
      converted_invoice_id: invoice_id,
      converted_invoice_type: invoice_type
    })
  end
end
