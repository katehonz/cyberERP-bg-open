defmodule CyberCore.Currencies.Currency do
  @moduledoc """
  Валута в системата.

  Базирана на ISO 4217 стандарта. Системата поддържа многовалутни операции
  с централизирана конверсия през базовата валута (BGN).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Currencies.ExchangeRate

  schema "currencies" do
    field :code, :string
    field :name, :string
    field :name_bg, :string
    field :symbol, :string
    field :decimal_places, :integer, default: 2
    field :is_active, :boolean, default: true
    field :is_base_currency, :boolean, default: false
    field :bnb_code, :string

    has_many :exchange_rates_from, ExchangeRate, foreign_key: :from_currency_id
    has_many :exchange_rates_to, ExchangeRate, foreign_key: :to_currency_id

    timestamps()
  end

  @doc false
  def changeset(currency, attrs) do
    currency
    |> cast(attrs, [
      :code,
      :name,
      :name_bg,
      :symbol,
      :decimal_places,
      :is_active,
      :is_base_currency,
      :bnb_code
    ])
    |> validate_required([:code, :name, :name_bg])
    |> validate_length(:code, is: 3)
    |> validate_format(:code, ~r/^[A-Z]{3}$/, message: "трябва да е 3 главни букви (ISO 4217)")
    |> validate_inclusion(:decimal_places, 0..6)
    |> validate_number(:decimal_places, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
  end

  @doc """
  Проверява дали валутата е базовата валута (BGN).
  """
  def base_currency?(%__MODULE__{is_base_currency: is_base}), do: is_base

  @doc """
  Връща форматирана сума с валутен символ.

  ## Примери

      iex> format_amount(%Currency{symbol: "лв.", decimal_places: 2}, Decimal.new("123.45"))
      "123.45 лв."

      iex> format_amount(%Currency{symbol: "€", decimal_places: 2}, Decimal.new("1234.50"))
      "1,234.50 €"
  """
  def format_amount(%__MODULE__{symbol: symbol, decimal_places: places}, amount) do
    formatted = Decimal.round(amount, places) |> Decimal.to_string(:normal)
    "#{formatted} #{symbol}"
  end
end
