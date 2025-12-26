defmodule CyberCore.Currencies.ExchangeRate do
  @moduledoc """
  Обменен курс между две валути.

  Всички курсове се съхраняват спрямо базовата валута (BGN) за централизирана конверсия.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias CyberCore.Currencies.Currency

  schema "exchange_rates" do
    belongs_to :from_currency, Currency
    belongs_to :to_currency, Currency

    field :rate, :decimal
    field :reverse_rate, :decimal
    field :valid_date, :date
    field :rate_source, :string, default: "manual"
    field :bnb_rate_id, :string
    field :is_active, :boolean, default: true
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(rate, attrs) do
    rate
    |> cast(attrs, [
      :from_currency_id,
      :to_currency_id,
      :rate,
      :valid_date,
      :rate_source,
      :bnb_rate_id,
      :is_active,
      :notes
    ])
    |> validate_required([:from_currency_id, :to_currency_id, :rate, :valid_date])
    |> foreign_key_constraint(:from_currency_id)
    |> foreign_key_constraint(:to_currency_id)
    |> validate_number(:rate, greater_than: 0)
    |> validate_inclusion(:rate_source, ~w(manual bnb ecb api))
    |> put_reverse_rate()
    |> unique_constraint([:from_currency_id, :to_currency_id, :valid_date],
      name: :exchange_rates_currencies_date_unique
    )
  end

  defp put_reverse_rate(changeset) do
    case get_change(changeset, :rate) do
      nil -> changeset
      rate -> put_change(changeset, :reverse_rate, Decimal.div(Decimal.new(1), rate))
    end
  end

  @doc """
  Конвертира сума по обменния курс.
  """
  def convert_amount(%__MODULE__{rate: rate}, amount) do
    Decimal.mult(amount, rate)
  end

  @doc """
  Проверява дали курсът е актуален (в рамките на последния работен ден).
  """
  def is_up_to_date?(%__MODULE__{valid_date: valid_date}) do
    today = Date.utc_today()
    days_diff = Date.diff(today, valid_date)

    case Date.day_of_week(today) do
      1 -> days_diff <= 3
      2 -> days_diff <= 1
      _ -> days_diff <= 1
    end
  end
end
