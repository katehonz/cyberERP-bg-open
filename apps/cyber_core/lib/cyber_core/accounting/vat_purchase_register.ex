defmodule CyberCore.Accounting.VatPurchaseRegister do
  @moduledoc """
  Дневник покупки (Purchase Register) според ЗДДС.

  Всяка регистрирана по ЗДДС компания трябва да води дневник на покупките,
  в който се вписват всички получени данъчни документи от доставчици.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "vat_purchase_register" do
    field :tenant_id, :integer

    # Период
    field :period_year, :integer
    field :period_month, :integer

    # Връзка към документ (полиморфна - може invoice, bank_transaction, etc.)
    field :document_id, :integer
    field :document_type_table, :string

    # Данни за документа
    field :document_date, :date
    field :tax_event_date, :date
    field :document_type, :string
    field :document_number, :string
    field :purchase_operation, :string

    # Данни за контрагент (доставчик)
    field :supplier_name, :string
    field :supplier_vat_number, :string
    field :supplier_country, :string
    field :supplier_eik, :string
    field :supplier_city, :string

    # Финансови данни
    field :taxable_base, :decimal
    field :vat_rate, :decimal
    field :vat_amount, :decimal
    field :total_amount, :decimal

    # За приспадане на ДДС
    field :is_deductible, :boolean, default: true
    field :deductible_vat_amount, :decimal

    # Detailed VAT operation codes (commercial product compliance)
    field :vat_operation_code, :string
    field :column_code, :string
    field :deductible_credit_type, :string, default: "full"
    field :vies_indicator, :string
    field :reverse_charge_subcode, :string
    field :is_triangular_operation, :boolean, default: false
    field :is_art_21_service, :boolean, default: false

    # Забележки
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(register, attrs) do
    register
    |> cast(attrs, [
      :tenant_id,
      :period_year,
      :period_month,
      :document_id,
      :document_type_table,
      :document_date,
      :tax_event_date,
      :document_type,
      :document_number,
      :purchase_operation,
      :supplier_name,
      :supplier_vat_number,
      :supplier_country,
      :supplier_eik,
      :supplier_city,
      :taxable_base,
      :vat_rate,
      :vat_amount,
      :total_amount,
      :is_deductible,
      :deductible_vat_amount,
      :vat_operation_code,
      :column_code,
      :deductible_credit_type,
      :vies_indicator,
      :reverse_charge_subcode,
      :is_triangular_operation,
      :is_art_21_service,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :period_year,
      :period_month,
      :document_date,
      :tax_event_date,
      :document_type,
      :document_number,
      :supplier_name,
      :taxable_base,
      :vat_rate,
      :vat_amount,
      :total_amount
    ])
    |> validate_number(:period_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_number(:vat_rate, greater_than_or_equal_to: 0)
    |> validate_inclusion(:deductible_credit_type, ["full", "partial", "none", "not_applicable"])
    |> validate_inclusion(:vies_indicator, ["к3", "к4", "к5", nil])
    |> validate_inclusion(:reverse_charge_subcode, ["01", "02", nil])
    |> calculate_deductible_vat()
  end

  defp calculate_deductible_vat(changeset) do
    is_deductible = get_field(changeset, :is_deductible, true)
    vat_amount = get_field(changeset, :vat_amount)

    deductible =
      if is_deductible and vat_amount do
        vat_amount
      else
        Decimal.new(0)
      end

    put_change(changeset, :deductible_vat_amount, deductible)
  end
end
