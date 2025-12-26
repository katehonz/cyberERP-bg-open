defmodule CyberCore.Currencies.BnbService do
  @moduledoc """
  BNB (Bulgarian National Bank) Exchange Rate Service
  """

  require Logger
  import SweetXml
  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Currencies.{Currency, ExchangeRate}
  alias Decimal, as: D

  @rates_url "https://www.bnb.bg/Statistics/StExternalSector/StExchangeRates/StERForeignCurrencies/?download=xml&lang=EN"

  def update_current_rates do
    Logger.info("Fetching BNB rates from #{@rates_url}")
    case fetch_xml(@rates_url) do
      {:ok, xml} ->
        case parse_bnb_xml(xml) do
          {:ok, {date, rates}} -> update_rates(date, rates)
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_xml(url) do
    case Finch.build(:get, url) |> Finch.request(CyberCore.Finch) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "BNB XML API returned status: #{status}"}
      {:error, reason} -> {:error, "Failed to fetch BNB rates: #{inspect(reason)}"}
    end
  end

  defp parse_bnb_xml(xml) do
    rows = xpath(xml, ~x"//ROW[GOLD[text()='1']]"l,
      code: ~x"./CODE/text()"s,
      rate: ~x"./RATE/text()"s,
      ratio: ~x"./RATIO/text()"s,
      date: ~x"./CURR_DATE/text()"s
    )
    
    date_str = rows |> List.first() |> Map.get(:date)
    {:ok, date} = Date.from_iso8601(date_str)

    rates = Enum.map(rows, fn row ->
      {:ok, rate_val} = D.cast(row.rate)
      {:ok, ratio_val} = D.cast(row.ratio)
      %{
        code: row.code,
        rate: D.div(rate_val, ratio_val),
        date: date
      }
    end)

    {:ok, {date, rates}}
  rescue
    e -> 
      Logger.error("Failed to parse BNB XML: #{inspect(e)}")
      {:error, :xml_parsing_failed}
  end

  defp update_rates(date, rates) do
    base_currency = Repo.get_by!(Currency, code: "BGN")

    updated_count =
      rates
      |> Enum.reduce(0, fn bnb_rate, count ->
        case update_single_rate(bnb_rate, date, base_currency) do
          {:ok, _} -> count + 1
          {:error, reason} ->
            Logger.error("Failed to update rate for #{bnb_rate.code}: #{inspect(reason)}")
            count
        end
      end)
    {:ok, updated_count}
  end

  defp update_single_rate(bnb_rate, date, base_currency) do
    case Repo.get_by(Currency, code: bnb_rate.code) do
      nil ->
        {:error, :currency_not_found}

      foreign_currency ->
        rate_attrs = %{
          from_currency_id: foreign_currency.id,
          to_currency_id: base_currency.id,
          rate: bnb_rate.rate,
          valid_date: date,
          rate_source: "bnb",
          is_active: true
        }

        case Repo.get_by(ExchangeRate, from_currency_id: foreign_currency.id, to_currency_id: base_currency.id, valid_date: date) do
          nil ->
            %ExchangeRate{}
            |> ExchangeRate.changeset(rate_attrs)
            |> Repo.insert()
          existing_rate ->
            existing_rate
            |> ExchangeRate.changeset(rate_attrs)
            |> Repo.update()
        end
    end
  end
end
