defmodule CyberCore.Currencies.EcbService do
  @moduledoc """
  ECB (European Central Bank) Exchange Rate Service

  Fetches exchange rates from the European Central Bank API.
  ECB provides EUR-based exchange rates for various currencies.

  API Documentation: https://www.ecb.europa.eu/stats/eurofxref/

  Important notes for Euro adoption in Bulgaria (2026):
  - When Bulgaria adopts EUR in 2026, this service will be used for historical BGN rates
  - For new companies starting from 2026, this will be the primary source for non-EUR rates
  - Rates are published on ECB business days (Mon-Fri, excluding ECB holidays)
  """

  require Logger
  import SweetXml
  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Currencies.{Currency, ExchangeRate}
  alias Decimal, as: D

  @current_rates_url "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml"
  @historical_rates_url "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.xml"

  # Fixed EUR/BGN rate (Bulgaria's currency board)
  @fixed_eur_bgn D.new("1.95583")

  @doc """
  Fetch exchange rates from ECB for a specific date.

  Returns EUR-based rates (1 EUR = X currency)
  """
  def fetch_rates_for_date(date \\ Date.utc_today()) do
    today = Date.utc_today()
    days_diff = Date.diff(today, date)

    url =
      if days_diff <= 90 do
        @current_rates_url
      else
        Logger.warning("Fetching from full ECB history (large file). Consider caching.")
        @historical_rates_url
      end

    Logger.info("Fetching ECB rates for date: #{date} from #{url}")

    case fetch_xml(url) do
      {:ok, xml} -> parse_ecb_xml(xml, date)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Update exchange rates in database from ECB for a specific date.

  For Bulgaria pre-2026: Converts EUR rates to BGN using fixed rate (1 EUR = 1.95583 BGN)
  For Bulgaria post-2026: Stores EUR-based rates directly
  """
  def update_rates_for_date(date \\ Date.utc_today()) do
    case fetch_rates_for_date(date) do
      {:ok, ecb_rates} ->
        # Get base currency (BGN or EUR)
        base_currency = get_base_currency!()
        is_eur_base = base_currency.code == "EUR"

        Logger.info("Updating ECB rates with base currency: #{base_currency.code}")

        # Get EUR currency for conversions
        eur_currency = Repo.get_by!(Currency, code: "EUR")

        updated_count =
          ecb_rates
          |> Enum.reduce(0, fn ecb_rate, count ->
            case update_single_rate(ecb_rate, date, is_eur_base, base_currency, eur_currency) do
              {:ok, _} ->
                count + 1

              {:error, reason} ->
                Logger.error("Failed to update rate for #{ecb_rate.code}: #{inspect(reason)}")
                count
            end
          end)

        {:ok, updated_count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update rates for current date (tries today, falls back to yesterday if needed).
  """
  def update_current_rates do
    today = Date.utc_today()

    case update_rates_for_date(today) do
      {:ok, count} when count > 0 ->
        {:ok, count}

      _ ->
        Logger.info("No rates for today, trying yesterday")
        yesterday = Date.add(today, -1)
        update_rates_for_date(yesterday)
    end
  end

  @doc """
  Update rates for a range of dates (business days only).
  """
  def update_rates_for_range(from_date, to_date) do
    from_date
    |> Date.range(to_date)
    |> Enum.filter(&is_business_day?/1)
    |> Enum.reduce(%{}, fn date, acc ->
      # Small delay to be respectful to ECB servers
      Process.sleep(300)

      case update_rates_for_date(date) do
        {:ok, count} ->
          Logger.info("Updated #{count} ECB rates for #{date}")
          Map.put(acc, date, count)

        {:error, reason} ->
          Logger.error("Failed to update ECB rates for #{date}: #{inspect(reason)}")
          Map.put(acc, date, 0)
      end
    end)
  end

  @doc """
  Get latest ECB rate for a currency pair.
  """
  def get_latest_rate(from_currency_id, to_currency_id) do
    ExchangeRate
    |> where([r], r.from_currency_id == ^from_currency_id)
    |> where([r], r.to_currency_id == ^to_currency_id)
    |> where([r], r.rate_source == "ecb")
    |> where([r], r.is_active == true)
    |> order_by([r], desc: r.valid_date)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  List of currencies supported by ECB.

  ECB provides rates for: USD, JPY, BGN, CZK, DKK, GBP, HUF, PLN, RON, SEK, CHF,
  ISK, NOK, TRY, AUD, BRL, CAD, CNY, HKD, IDR, ILS, INR, KRW, MXN, MYR, NZD,
  PHP, SGD, THB, ZAR
  """
  def supported_currencies do
    ~w(USD JPY BGN CZK DKK GBP HUF PLN RON SEK CHF ISK NOK TRY AUD BRL CAD CNY HKD IDR ILS INR KRW MXN MYR NZD PHP SGD THB ZAR)
  end

  @doc """
  Check if a currency is supported by ECB.
  """
  def currency_supported?(code) do
    code in supported_currencies()
  end

  # Private functions

  defp fetch_xml(url) do
    case Finch.build(:get, url) |> Finch.request(CyberCore.Finch) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "ECB API returned status: #{status}"}
      {:error, reason} -> {:error, "Failed to fetch ECB rates: #{inspect(reason)}"}
    end
  end

  defp parse_ecb_xml(xml, target_date) do
    target_date_str = Date.to_iso8601(target_date)

    # Parse ECB XML format:
    # <gesmes:Envelope>
    #   <Cube>
    #     <Cube time="2025-05-28">
    #       <Cube currency="USD" rate="1.0847"/>
    #       <Cube currency="GBP" rate="0.8532"/>
    #     </Cube>
    #   </Cube>
    # </gesmes:Envelope>

    time_cubes =
      xml
      |> xpath(~x"//Cube/Cube[@time]"l,
        time: ~x"./@time"s,
        rates: [
          ~x"./Cube"l,
          code: ~x"./@currency"s,
          rate: ~x"./@rate"s
        ]
      )

    # Find rates for target date
    case Enum.find(time_cubes, fn cube -> cube.time == target_date_str end) do
      nil ->
        # Try to find closest earlier date
        find_closest_rates(time_cubes, target_date)

      cube ->
        rates =
          Enum.map(cube.rates, fn r ->
            %{code: r.code, rate: r.rate, date: cube.time}
          end)

        Logger.info("Found #{length(rates)} ECB rates for #{target_date}")
        {:ok, rates}
    end
  end

  defp find_closest_rates(time_cubes, target_date) do
    closest =
      time_cubes
      |> Enum.map(fn cube ->
        case Date.from_iso8601(cube.time) do
          {:ok, date} -> {date, cube}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn {date, _} -> Date.compare(date, target_date) != :gt end)
      |> Enum.max_by(fn {date, _} -> Date.to_erl(date) end, fn -> nil end)

    case closest do
      nil ->
        {:error, "No ECB rates found for #{target_date} or earlier"}

      {found_date, cube} ->
        rates =
          Enum.map(cube.rates, fn r ->
            %{code: r.code, rate: r.rate, date: cube.time}
          end)

        Logger.info(
          "No exact ECB rates for #{target_date}, using closest earlier date: #{found_date} (#{length(rates)} rates)"
        )

        {:ok, rates}
    end
  end

  defp update_single_rate(ecb_rate, date, is_eur_base, base_currency, eur_currency) do
    # Find currency by code
    case Repo.get_by(Currency, code: ecb_rate.code) do
      nil ->
        Logger.warning("Currency #{ecb_rate.code} not found in database")
        {:error, :currency_not_found}

      foreign_currency ->
        # Parse ECB rate (EUR to foreign currency)
        {:ok, eur_to_foreign} = D.cast(ecb_rate.rate)

        {rate, from_id, to_id} =
          if is_eur_base do
            # Post-2026: Store EUR -> Foreign directly
            {eur_to_foreign, eur_currency.id, foreign_currency.id}
          else
            # Pre-2026: Convert EUR rate to BGN rate
            # If 1 EUR = X USD, and 1 EUR = 1.95583 BGN
            # Then 1 USD = 1.95583 / X BGN
            bgn_rate = D.div(@fixed_eur_bgn, eur_to_foreign)
            {bgn_rate, foreign_currency.id, base_currency.id}
          end

        # Check if rate already exists for this date
        case Repo.get_by(ExchangeRate,
               from_currency_id: from_id,
               to_currency_id: to_id,
               valid_date: date
             ) do
          nil ->
            # Create new rate
            %ExchangeRate{}
            |> ExchangeRate.changeset(%{
              from_currency_id: from_id,
              to_currency_id: to_id,
              rate: rate,
              valid_date: date,
              rate_source: "ecb",
              bnb_rate_id: "ECB_#{ecb_rate.code}_#{date}",
              is_active: true
            })
            |> Repo.insert()
            |> case do
              {:ok, rate} ->
                Logger.info("Created new ECB rate for #{ecb_rate.code} on #{date}: #{rate.rate}")
                {:ok, rate}

              {:error, changeset} ->
                {:error, changeset}
            end

          existing_rate ->
            # Update existing rate
            existing_rate
            |> ExchangeRate.changeset(%{
              rate: rate,
              rate_source: "ecb",
              bnb_rate_id: "ECB_#{ecb_rate.code}_#{date}"
            })
            |> Repo.update()
            |> case do
              {:ok, rate} ->
                Logger.info("Updated ECB rate for #{ecb_rate.code} on #{date}: #{rate.rate}")
                {:ok, rate}

              {:error, changeset} ->
                {:error, changeset}
            end
        end
    end
  end

  defp get_base_currency! do
    Repo.one!(from c in Currency, where: c.is_base_currency == true)
  end

  defp is_business_day?(date) do
    day = Date.day_of_week(date)
    # Monday = 1, Sunday = 7
    day >= 1 and day <= 5
  end
end
