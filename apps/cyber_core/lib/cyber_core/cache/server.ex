defmodule CyberCore.Cache.Server do
  @moduledoc """
  GenServer за управление на ETS таблици за кеширане на често използвани ERP данни.

  Този сървър управлява няколко ETS таблици за различни типове данни:
  - `:cache_accounts` - Сметкоплан и счетоводни настройки
  - `:cache_nomenclatures` - КН кодове и номенклатури
  - `:cache_measurement_units` - Мерни единици
  - `:cache_vat_rates` - ДДС ставки
  - `:cache_settings` - Системни настройки

  ## Характеристики:
  - Concurrent reads - ETS таблиците са с :read_concurrency
  - Event-based invalidation чрез Phoenix.PubSub
  - Warm-up при старт на сървъра
  - Fault-tolerant чрез OTP supervision
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias CyberCore.Repo
  alias CyberCore.Inventory

  @cache_tables [
    :cache_accounts,
    :cache_nomenclatures,
    :cache_measurement_units,
    :cache_vat_rates,
    :cache_settings
  ]

  # Client API

  @doc """
  Стартира Cache сървъра.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Взима данни от кеша. Ако няма данни, зарежда ги от базата.
  """
  def get(table, key, loader_fn \\ nil) do
    case :ets.lookup(table, key) do
      [{^key, value, _timestamp}] ->
        {:ok, value}

      [] ->
        if loader_fn do
          load_and_cache(table, key, loader_fn)
        else
          {:error, :not_found}
        end
    end
  end

  @doc """
  Взима всички записи от дадена таблица.
  """
  def get_all(table) do
    :ets.tab2list(table)
    |> Enum.map(fn {key, value, _timestamp} -> {key, value} end)
  end

  @doc """
  Кешира данни директно.
  """
  def put(table, key, value) do
    GenServer.call(__MODULE__, {:put, table, key, value})
  end

  @doc """
  Инвалидира конкретен запис.
  """
  def invalidate(table, key) do
    GenServer.cast(__MODULE__, {:invalidate, table, key})
  end

  @doc """
  Инвалидира цяла таблица.
  """
  def invalidate_table(table) do
    GenServer.cast(__MODULE__, {:invalidate_table, table})
  end

  @doc """
  Инвалидира всички таблици.
  """
  def invalidate_all do
    GenServer.cast(__MODULE__, :invalidate_all)
  end

  @doc """
  Презарежда данните за конкретна таблица от базата.
  """
  def reload(table) do
    GenServer.call(__MODULE__, {:reload, table})
  end

  @doc """
  Връща статистика за кеша.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Създаваме ETS таблиците
    tables =
      for table <- @cache_tables, into: %{} do
        tid =
          :ets.new(table, [
            :named_table,
            :set,
            :public,
            read_concurrency: true,
            write_concurrency: false
          ])

        {table, tid}
      end

    # Subscrib-ваме се за invalidation events
    Phoenix.PubSub.subscribe(CyberCore.PubSub, "cache:invalidate")

    # Warm-up - зареждаме често използваните данни
    spawn(fn -> warm_up() end)

    Logger.info("Cache.Server started with tables: #{inspect(@cache_tables)}")

    {:ok, %{tables: tables, hits: 0, misses: 0}}
  end

  @impl true
  def handle_call({:put, table, key, value}, _from, state) do
    timestamp = System.system_time(:second)
    :ets.insert(table, {key, value, timestamp})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:reload, table}, _from, state) do
    result = reload_table(table)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      for table <- @cache_tables, into: %{} do
        info = :ets.info(table)
        {table, %{size: info[:size], memory: info[:memory]}}
      end

    full_stats =
      Map.merge(stats, %{
        hits: state.hits,
        misses: state.misses,
        hit_rate: calculate_hit_rate(state.hits, state.misses)
      })

    {:reply, full_stats, state}
  end

  @impl true
  def handle_cast({:invalidate, table, key}, state) do
    :ets.delete(table, key)
    Logger.debug("Cache invalidated: #{table}/#{key}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalidate_table, table}, state) do
    :ets.delete_all_objects(table)
    Logger.debug("Cache table cleared: #{table}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:invalidate_all, state) do
    for table <- @cache_tables do
      :ets.delete_all_objects(table)
    end

    Logger.info("All cache tables cleared")
    {:noreply, state}
  end

  @impl true
  def handle_info({:invalidate, table, key}, state) do
    :ets.delete(table, key)
    {:noreply, state}
  end

  @impl true
  def handle_info({:invalidate_table, table}, state) do
    :ets.delete_all_objects(table)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp load_and_cache(table, key, loader_fn) do
    case loader_fn.(key) do
      {:ok, value} ->
        timestamp = System.system_time(:second)
        :ets.insert(table, {key, value, timestamp})
        {:ok, value}

      {:error, _} = error ->
        error
    end
  end

  defp warm_up do
    Logger.info("Starting cache warm-up...")

    # Зареждаме мерни единици
    load_measurement_units()

    # TODO: Fix this after schema refactoring for vat_rates
    # Зареждаме ДДС ставки
    # load_vat_rates()

    # Зареждаме често използваните КН кодове (топ 100)
    load_top_cn_codes(100)

    Logger.info("Cache warm-up completed")
  end

  defp load_measurement_units do
    try do
      units = Inventory.list_measurement_units()

      for unit <- units do
        timestamp = System.system_time(:second)
        :ets.insert(:cache_measurement_units, {unit.id, unit, timestamp})
        :ets.insert(:cache_measurement_units, {"code:#{unit.code}", unit, timestamp})
      end

      Logger.debug("Loaded #{length(units)} measurement units into cache")
    rescue
      e ->
        Logger.error("Failed to load measurement units: #{inspect(e)}")
    end
  end

  defp load_vat_rates do
    try do
      rates =
        CyberCore.Accounting.VatRate
        |> where([v], v.is_active == true)
        |> order_by([v], desc: v.rate)
        |> Repo.all()

      for rate <- rates do
        timestamp = System.system_time(:second)
        :ets.insert(:cache_vat_rates, {rate.id, rate, timestamp})

        if rate.code do
          :ets.insert(:cache_vat_rates, {"code:#{rate.code}", rate, timestamp})
        end
      end

      Logger.debug("Loaded #{length(rates)} VAT rates into cache")
    rescue
      e ->
        Logger.error("Failed to load VAT rates: #{inspect(e)}")
    end
  end

  defp load_top_cn_codes(limit) do
    try do
      # Зареждаме най-новите/използваните КН кодове
      codes =
        CyberCore.Inventory.CnNomenclature
        |> order_by([c], desc: c.year, asc: c.code)
        |> limit(^limit)
        |> Repo.all()

      for code <- codes do
        timestamp = System.system_time(:second)
        :ets.insert(:cache_nomenclatures, {code.id, code, timestamp})
        :ets.insert(:cache_nomenclatures, {"cn:#{code.year}:#{code.code}", code, timestamp})
      end

      Logger.debug("Loaded #{length(codes)} CN codes into cache")
    rescue
      e ->
        Logger.error("Failed to load CN codes: #{inspect(e)}")
    end
  end

  defp reload_table(:cache_measurement_units) do
    :ets.delete_all_objects(:cache_measurement_units)
    load_measurement_units()
    :ok
  end

  defp reload_table(:cache_vat_rates) do
    :ets.delete_all_objects(:cache_vat_rates)
    # TODO: Fix this after schema refactoring for vat_rates
    # load_vat_rates()
    :ok
  end

  defp reload_table(:cache_nomenclatures) do
    :ets.delete_all_objects(:cache_nomenclatures)
    load_top_cn_codes(100)
    :ok
  end

  defp reload_table(table) do
    Logger.warning("No reload function defined for table: #{table}")
    {:error, :not_implemented}
  end

  defp calculate_hit_rate(_hits, 0), do: 0.0
  defp calculate_hit_rate(hits, misses), do: hits / (hits + misses) * 100
end
