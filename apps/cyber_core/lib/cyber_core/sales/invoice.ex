defmodule CyberCore.Sales.Invoice do
  @moduledoc """
  Фактури за продажби.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Типове документи за ПРОДАЖБИ според ППЗДДС 2025 (Правилник за прилагане на ЗДДС)
  @vat_document_types %{
    "01" => "Фактура",
    "02" => "Дебитно известие",
    "03" => "Кредитно известие",
    "04" => "Регистър на стоки под режим складиране (изпратени)",
    "07" => "Митническа декларация/документ",
    "09" => "Протокол или друг документ",
    "11" => "Фактура - касова отчетност",
    "12" => "Дебитно известие - касова отчетност",
    "13" => "Кредитно известие - касова отчетност",
    "23" => "Кредитно известие по чл. 126б, ал. 1 ЗДДС",
    "29" => "Протокол по чл. 126б, ал. 2 и 7 ЗДДС",
    "50" => "Протокол за начисляване на изискуемия ДДС за горива",
    "81" => "Отчет за извършените продажби",
    "82" => "Отчет при специален ред на облагане",
    "83" => "Отчет при предоставени компенсации за горива",
    "84" => "Отчет за продажби на хляб",
    "85" => "Отчет за продажби на брашно",
    "91" => "Протокол за изискуемия данък по чл. 151в, ал. 3",
    "93" => "Протокол по чл. 151в, ал. 7 (не прилага спец. режим)",
    "94" => "Протокол по чл. 151в, ал. 7 (прилага спец. режим)",
    "95" => "Протокол за безвъзмездно предоставяне на хранителни стоки"
  }

  # Операции при покупка (0-6)
  @vat_purchase_operations %{
    "0" => "Друго",
    "1" => "Данъчно събитие - чл. 25, ал. 2 или чл. 25, ал. 3",
    "2" => "Получена стока и/или услуга от доставчик - регистрирано лице",
    "3" => "Получени услуги от доставчик по чл. 21, ал. 2 ЗДДС",
    "4" => "Получени стоки от доставчик по чл. 21, ал. 2 ЗДДС"
  }

  # Операции при продажба (0-10, 9001-9002)
  @vat_sales_operations %{
    "0" => "Друго",
    "1" => "Данъчно събитие по чл. 25, ал. 2 или чл. 25, ал. 3",
    "2" => "Доставка на стока и/или услуга в страната",
    "3" => "Вътреобщностна доставка на стоки",
    "4" => "Експорт на стоки",
    "5" => "Доставка на услуги с място на изпълнение извън страната"
  }

  # Основания за неначисляване на ДДС (0% ставка)
  @vat_zero_reasons %{
    "vod" => "Чл. 53, ал. 1 от ЗДДС - Вътреобщностна доставка (ВОД)",
    "export" => "Чл. 28 от ЗДДС - Износ на стоки",
    "art21" => "Чл. 21, ал. 2 от ЗДДС - Доставка с място на изпълнение извън България",
    "reverse_charge" => "Чл. 82, ал. 2 и 3 от ЗДДС - Обратно начисляване",
    "art46" => "Чл. 46 от ЗДДС - Освободени доставки",
    "art13" => "Чл. 13 от ЗДДС - Не е доставка по смисъла на ЗДДС",
    "other" => "Друго основание (посочете в забележки)"
  }

  @statuses ~w(draft issued paid partially_paid overdue cancelled)

  schema "invoices" do
    field :tenant_id, :integer

    # Номериране
    field :invoice_no, :string
    field :invoice_type, :string, default: "standard"
    field :status, :string, default: "draft"

    # Дати
    field :issue_date, :date
    field :due_date, :date
    field :tax_event_date, :date

    # Връзки
    belongs_to :contact, CyberCore.Contacts.Contact
    field :billing_name, :string
    field :billing_address, :string
    field :billing_vat_number, :string
    field :billing_company_id, :string

    # Финансови данни
    field :subtotal, :decimal, default: Decimal.new(0)
    field :tax_amount, :decimal, default: Decimal.new(0)
    field :total_amount, :decimal, default: Decimal.new(0)
    field :paid_amount, :decimal, default: Decimal.new(0)
    field :currency, :string, default: "BGN"

    # Начин на плащане
    # "cash", "card", "bank"
    field :payment_method, :string

    belongs_to :bank_account, CyberCore.Bank.BankAccount,
      foreign_key: :bank_account_id,
      type: :integer

    # Допълнителна информация
    field :notes, :string
    field :payment_terms, :string
    field :reference, :string

    # Връзка с родителска фактура (за кредитни ноти)
    field :parent_invoice_id, :integer

    # Кодове за ДДС според ППЗДДС (Правилник за прилагане на ЗДДС)
    field :vat_document_type, :string
    field :vat_purchase_operation, :string
    field :vat_sales_operation, :string
    field :vat_additional_operation, :string
    field :vat_additional_data, :string
    # Основание за 0% ДДС
    field :vat_reason, :string

    # OSS Режим
    # Държава членка на потребление
    field :oss_country, :string
    # ДДС ставка в OSS държавата
    field :oss_vat_rate, :decimal

    # Редове на фактурата
    has_many :invoice_lines, CyberCore.Sales.InvoiceLine

    timestamps()
  end

  def vat_document_types, do: @vat_document_types
  def vat_purchase_operations, do: @vat_purchase_operations
  def vat_sales_operations, do: @vat_sales_operations
  def vat_zero_reasons, do: @vat_zero_reasons

  @doc false
  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [
      :tenant_id,
      :invoice_no,
      :invoice_type,
      :status,
      :issue_date,
      :due_date,
      :tax_event_date,
      :contact_id,
      :billing_name,
      :billing_address,
      :billing_vat_number,
      :billing_company_id,
      :subtotal,
      :tax_amount,
      :total_amount,
      :paid_amount,
      :currency,
      :notes,
      :payment_terms,
      :reference,
      :parent_invoice_id,
      :vat_document_type,
      :vat_purchase_operation,
      :vat_sales_operation,
      :vat_additional_operation,
      :vat_additional_data,
      # New fields
      :payment_method,
      :bank_account_id,
      :vat_reason,
      :oss_country,
      :oss_vat_rate
    ])
    |> validate_required([
      :tenant_id,
      :invoice_no,
      :issue_date,
      :contact_id,
      :billing_name,
      :vat_document_type
    ])
    |> validate_inclusion(:vat_document_type, Map.keys(@vat_document_types))
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:invoice_no, max: 50)
    |> validate_length(:currency, is: 3)
    |> unique_constraint([:tenant_id, :invoice_no])
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:bank_account_id)
    |> validate_vat_operations()
  end

  defp validate_vat_operations(changeset) do
    changeset
    |> validate_optional_inclusion(:vat_purchase_operation, Map.keys(@vat_purchase_operations))
    |> validate_optional_inclusion(:vat_sales_operation, Map.keys(@vat_sales_operations))
  end

  defp validate_optional_inclusion(changeset, field, values) do
    case get_field(changeset, field) do
      nil -> changeset
      "" -> changeset
      _value -> validate_inclusion(changeset, field, values)
    end
  end
end
