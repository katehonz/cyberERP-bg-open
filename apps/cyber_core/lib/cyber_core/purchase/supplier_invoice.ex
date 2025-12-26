defmodule CyberCore.Purchase.SupplierInvoice do
  @moduledoc """
  Фактури от доставчици (получени фактури).
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Типове документи за ПОКУПКИ според ППЗДДС 2025 (Правилник за прилагане на ЗДДС)
  @vat_document_types %{
    "01" => "Фактура",
    "02" => "Дебитно известие",
    "03" => "Кредитно известие",
    "05" => "Регистър на стоки под режим складиране (получени)",
    "07" => "Митническа декларация/документ",
    "09" => "Протокол или друг документ",
    "11" => "Фактура - касова отчетност",
    "12" => "Дебитно известие - касова отчетност",
    "13" => "Кредитно известие - касова отчетност",
    "23" => "Кредитно известие по чл. 126б, ал. 1 ЗДДС",
    "92" => "Протокол за данъчния кредит по чл. 151г, ал. 8"
  }

  # Операции при покупка според ППЗДДС
  @vat_purchase_operations %{
    "0" => "Друго",
    "1" => "Данъчно събитие - чл. 25, ал. 2 или чл. 25, ал. 3",
    "2" => "Получена стока и/или услуга от доставчик - регистрирано лице",
    "3" => "Получени услуги от доставчик по чл. 21, ал. 2 ЗДДС",
    "4" => "Получени стоки от доставчик по чл. 21, ал. 2 ЗДДС"
  }

  @statuses ~w(draft received approved paid partially_paid overdue cancelled)

  schema "supplier_invoices" do
    field :tenant_id, :integer

    # Номериране
    field :invoice_no, :string
    field :supplier_invoice_no, :string
    field :status, :string, default: "draft"

    # Дати
    field :invoice_date, :date
    field :due_date, :date
    field :received_date, :date
    field :tax_event_date, :date

    # Връзки
    belongs_to :supplier, CyberCore.Contacts.Contact
    belongs_to :purchase_order, CyberCore.Purchase.PurchaseOrder

    field :supplier_name, :string
    field :supplier_address, :string
    field :supplier_vat_number, :string

    # Финансови данни
    field :subtotal, :decimal, default: Decimal.new(0)
    field :tax_amount, :decimal, default: Decimal.new(0)
    field :total_amount, :decimal, default: Decimal.new(0)
    field :paid_amount, :decimal, default: Decimal.new(0)
    field :currency, :string, default: "BGN"

    # Допълнителна информация
    field :notes, :string
    field :payment_terms, :string
    field :reference, :string

    # Кодове за ДДС според ППЗДДС (Правилник за прилагане на ЗДДС)
    field :vat_document_type, :string
    field :vat_purchase_operation, :string
    field :vat_additional_data, :string

    # Редове на фактурата
    has_many :supplier_invoice_lines, CyberCore.Purchase.SupplierInvoiceLine

    timestamps()
  end

  def vat_document_types, do: @vat_document_types
  def vat_purchase_operations, do: @vat_purchase_operations

  @doc false
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :tenant_id,
      :invoice_no,
      :supplier_invoice_no,
      :status,
      :invoice_date,
      :due_date,
      :received_date,
      :tax_event_date,
      :supplier_id,
      :purchase_order_id,
      :supplier_name,
      :supplier_address,
      :supplier_vat_number,
      :subtotal,
      :tax_amount,
      :total_amount,
      :paid_amount,
      :currency,
      :notes,
      :payment_terms,
      :reference,
      :vat_document_type,
      :vat_purchase_operation,
      :vat_additional_data
    ])
    |> validate_required([
      :tenant_id,
      :invoice_no,
      :supplier_invoice_no,
      :invoice_date,
      :supplier_id,
      :supplier_name,
      :vat_document_type
    ])
    |> validate_inclusion(:vat_document_type, Map.keys(@vat_document_types))
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:invoice_no, max: 50)
    |> validate_length(:supplier_invoice_no, max: 50)
    |> validate_length(:currency, is: 3)
    |> unique_constraint([:tenant_id, :invoice_no])
    |> foreign_key_constraint(:supplier_id)
    |> validate_vat_operations()
  end

  defp validate_vat_operations(changeset) do
    validate_optional_inclusion(
      changeset,
      :vat_purchase_operation,
      Map.keys(@vat_purchase_operations)
    )
  end

  defp validate_optional_inclusion(changeset, field, values) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _value -> validate_inclusion(changeset, field, values)
    end
  end
end
