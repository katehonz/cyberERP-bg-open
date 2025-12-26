defmodule CyberCore.Accounting.VatSalesRegister do
  @moduledoc """
  Дневник продажби (Sales Register) според ЗДДС.

  Всяка регистрирана по ЗДДС компания трябва да води дневник на продажбите,
  в който се вписват всички издадени данъчни документи.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Sales.Invoice

  schema "vat_sales_register" do
    field :tenant_id, :integer

    # Период
    field :period_year, :integer
    field :period_month, :integer

    # Връзка към фактура
    belongs_to :invoice, Invoice

    # Данни за документа
    field :document_date, :date
    field :tax_event_date, :date
    field :document_type, :string
    field :document_number, :string
    field :sales_operation, :string

    # Данни за контрагент
    field :recipient_name, :string
    field :recipient_vat_number, :string
    field :recipient_country, :string
    field :recipient_eik, :string
    field :recipient_city, :string

    # Финансови данни
    field :taxable_base, :decimal
    field :vat_rate, :decimal
    field :vat_amount, :decimal
    field :total_amount, :decimal

    # Detailed VAT operation codes (commercial product compliance)
    field :vat_operation_code, :string
    field :column_code, :string
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
      :invoice_id,
      :document_date,
      :tax_event_date,
      :document_type,
      :document_number,
      :sales_operation,
      :recipient_name,
      :recipient_vat_number,
      :recipient_country,
      :recipient_eik,
      :recipient_city,
      :taxable_base,
      :vat_rate,
      :vat_amount,
      :total_amount,
      :vat_operation_code,
      :column_code,
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
      :recipient_name,
      :taxable_base,
      :vat_rate,
      :vat_amount,
      :total_amount
    ])
    |> validate_number(:period_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_number(:vat_rate, greater_than_or_equal_to: 0)
    |> validate_inclusion(:vies_indicator, ["к3", "к4", "к5", nil])
    |> validate_inclusion(:reverse_charge_subcode, ["01", "02", nil])
    |> foreign_key_constraint(:invoice_id)
  end

  @doc """
  Създава запис в дневника от фактура.
  Автоматично определя правилния VAT operation code според данъчната ставка и вида на доставката.
  """
  def from_invoice(%Invoice{} = invoice) do
    vat_rate = calculate_vat_rate(invoice.subtotal, invoice.tax_amount)
    {vat_op_code, column_code} = determine_vat_operation_code(invoice, vat_rate)

    %{
      tenant_id: invoice.tenant_id,
      period_year: invoice.tax_event_date.year,
      period_month: invoice.tax_event_date.month,
      invoice_id: invoice.id,
      document_date: invoice.issue_date,
      tax_event_date: invoice.tax_event_date,
      document_type: invoice.vat_document_type,
      document_number: invoice.invoice_no,
      sales_operation: invoice.vat_sales_operation,
      recipient_name: invoice.billing_name,
      recipient_vat_number: invoice.billing_vat_number,
      recipient_country: "BG",
      recipient_eik: invoice.billing_company_id,
      taxable_base: invoice.subtotal,
      vat_rate: vat_rate,
      vat_amount: invoice.tax_amount,
      total_amount: invoice.total_amount,
      vat_operation_code: vat_op_code,
      column_code: column_code,
      vies_indicator: determine_vies_indicator(invoice),
      is_triangular_operation: false,
      is_art_21_service: false
    }
  end

  # Автоматично определя VAT operation code според данъчната ставка.
  # Връща tuple {operation_code, column_code}.
  defp determine_vat_operation_code(_invoice, vat_rate) do
    cond do
      # 20% standard rate
      Decimal.compare(vat_rate, Decimal.new("20.00")) == :eq ->
        {"2-11", "про11"}

      # 9% reduced rate
      Decimal.compare(vat_rate, Decimal.new("9.00")) == :eq ->
        {"2-17", "про17"}

      # 0% or exempt - default to standard
      true ->
        {"2-11", "про11"}
    end
  end

  # Определя VIES индикатор ако е приложимо.
  defp determine_vies_indicator(invoice) do
    # Check if recipient has EU VAT number (starts with country code)
    cond do
      is_eu_vat_number?(invoice.billing_vat_number) -> "к3"
      true -> nil
    end
  end

  defp is_eu_vat_number?(nil), do: false

  defp is_eu_vat_number?(vat_number) when is_binary(vat_number) do
    eu_prefixes =
      ~w(AT BE BG CY CZ DE DK EE ES FI FR GB GR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK)

    Enum.any?(eu_prefixes, fn prefix ->
      String.starts_with?(String.upcase(vat_number), prefix)
    end) && !String.starts_with?(String.upcase(vat_number), "BG")
  end

  defp is_eu_vat_number?(_), do: false

  defp calculate_vat_rate(subtotal, tax_amount) do
    if Decimal.gt?(subtotal, 0) do
      Decimal.div(tax_amount, subtotal)
      |> Decimal.mult(100)
      |> Decimal.round(2)
    else
      Decimal.new(0)
    end
  end
end
