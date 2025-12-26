defmodule CyberCore.Settings.CompanySettings do
  @moduledoc """
  Настройки на фирмата - основна информация, ДДС номер, адреси, банкови данни.

  Тези данни се използват в:
  - ДДС декларации (DEKLAR.TXT)
  - Дневник продажби (PRODAGBI.TXT)
  - Дневник покупки (POKUPKI.TXT)
  - Фактури
  - Отчети
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "company_settings" do
    field :tenant_id, :integer

    # Основна информация
    field :company_name, :string
    field :company_name_en, :string

    # Данъчна информация
    field :vat_number, :string
    field :eik, :string
    field :is_vat_registered, :boolean, default: true
    field :vat_registration_date, :date

    # Адрес
    field :address, :string
    field :city, :string
    field :postal_code, :string
    field :country, :string, default: "BG"

    # Контактна информация
    field :phone, :string
    field :email, :string
    field :website, :string

    # Банкова информация
    field :bank_name, :string
    field :bank_bic, :string
    field :bank_iban, :string

    # Правно лице
    field :mol_name, :string
    field :mol_position, :string
    field :accountant_name, :string

    # Допълнителни настройки
    field :default_currency, :string, default: "BGN"
    field :default_vat_rate, :decimal
    field :use_multicurrency, :boolean, default: false

    # Настройки за номерация на документи (10-цифрена с водеща нула)
    field :invoice_prefix, :string
    field :invoice_next_number, :integer, default: 1

    # Номерация за продажби (фактури, ДИ, КИ) - 10 цифри с водеща нула
    field :sales_invoice_next_number, :integer, default: 1

    # Номерация за протоколи ВОП (вътреобщностно придобиване) - 10 цифри с водеща нула
    field :vop_protocol_next_number, :integer, default: 1

    # Логотип
    field :logo_url, :string

    # Забележки
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [
      :tenant_id,
      :company_name,
      :company_name_en,
      :vat_number,
      :eik,
      :is_vat_registered,
      :vat_registration_date,
      :address,
      :city,
      :postal_code,
      :country,
      :phone,
      :email,
      :website,
      :bank_name,
      :bank_bic,
      :bank_iban,
      :mol_name,
      :mol_position,
      :accountant_name,
      :default_currency,
      :default_vat_rate,
      :use_multicurrency,
      :invoice_prefix,
      :invoice_next_number,
      :sales_invoice_next_number,
      :vop_protocol_next_number,
      :logo_url,
      :notes
    ])
    |> validate_required([:tenant_id, :company_name, :vat_number])
    |> validate_format(:vat_number, ~r/^BG\d{9,10}$/,
      message: "ДДС номер трябва да е във формат BGxxxxxxxxx"
    )
    |> validate_format(:eik, ~r/^\d{9,13}$/, message: "ЕИК трябва да е 9-13 цифри")
    |> validate_format(:email, ~r/@/, message: "Невалиден имейл")
    |> validate_inclusion(:country, [
      "BG",
      "RO",
      "GR",
      "TR",
      "RS",
      "MK",
      "DE",
      "AT",
      "IT",
      "FR",
      "ES",
      "UK",
      "NL"
    ])
    |> validate_number(:default_vat_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:tenant_id)
  end

  @doc """
  Форматира ДДС номера за NAP файлове (15 символа, ляво подравнен).
  """
  def format_vat_number_for_nap(%__MODULE__{vat_number: vat_number}) do
    String.pad_trailing(vat_number || "", 15)
  end

  @doc """
  Форматира име на фирмата за NAP файлове (ограничение до определена дължина).
  """
  def format_company_name_for_nap(%__MODULE__{company_name: name}, max_length \\ 100) do
    String.pad_trailing(String.slice(name || "", 0, max_length), max_length)
  end
end
