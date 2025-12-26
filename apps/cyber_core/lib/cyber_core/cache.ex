defmodule CyberCore.Cache do
  @moduledoc """
  Публично API за ETS кеш система на CyberERP.

  Този модул предоставя удобни функции за кеширане и взимане на често използвани данни:
  - Номенклатури (КН кодове, мерни единици)
  - Сметкоплан и счетоводни настройки
  - ДДС ставки
  - Системни настройки

  ## Примери

      # Взимане на мерна единица по код
      {:ok, unit} = Cache.get_measurement_unit_by_code("PCE")

      # Взимане на ДДС ставка
      {:ok, vat_rate} = Cache.get_vat_rate_by_code("S")

      # Взимане на КН код за текущата година
      {:ok, cn_code} = Cache.get_cn_code("01012100")

      # Инвалидиране при промяна
      Cache.invalidate_measurement_units()

  ## Event-based Invalidation

  Модулът автоматично слуша за промени в данните и инвалидира кеша при нужда.
  Използва Phoenix.PubSub за broadcast на invalidation события.
  """

  import Ecto.Query
  alias CyberCore.Cache.Server
  alias CyberCore.{Repo, Accounting, Inventory}

  # Measurement Units

  @doc """
  Взима мерна единица по ID.
  """
  def get_measurement_unit(id) do
    Server.get(:cache_measurement_units, id, fn id ->
      case Inventory.get_measurement_unit(id) do
        nil -> {:error, :not_found}
        unit -> {:ok, unit}
      end
    end)
  end

  @doc """
  Взима мерна единица по код (напр. "PCE", "KGM").
  """
  def get_measurement_unit_by_code(code) do
    key = "code:#{code}"

    Server.get(:cache_measurement_units, key, fn _key ->
      case Inventory.get_measurement_unit_by_code(code) do
        nil -> {:error, :not_found}
        unit -> {:ok, unit}
      end
    end)
  end

  @doc """
  Взима всички мерни единици.
  """
  def list_measurement_units do
    case Server.get_all(:cache_measurement_units) do
      [] ->
        # Ако кешът е празен, зареди от базата
        units = Inventory.list_measurement_units()

        for unit <- units do
          Server.put(:cache_measurement_units, unit.id, unit)
        end

        units

      cached ->
        # Вземи само unit value-тата, игнорирай кеш ключовете
        cached
        |> Enum.map(fn {_key, value} -> value end)
        |> Enum.uniq_by(& &1.id)
    end
  end

  @doc """
  Инвалидира кеша на мерните единици.
  """
  def invalidate_measurement_units do
    Server.invalidate_table(:cache_measurement_units)
    broadcast_invalidation(:cache_measurement_units)
  end

  # VAT Rates

  @doc """
  Взима ДДС ставка по ID.
  """
  def get_vat_rate(id) do
    Server.get(:cache_vat_rates, id, fn id ->
      case Accounting.get_vat_rate(id) do
        nil -> {:error, :not_found}
        rate -> {:ok, rate}
      end
    end)
  end

  @doc """
  Взима ДДС ставка по код (напр. "S" за Standard, "Z" за Zero).
  """
  def get_vat_rate_by_code(code) do
    key = "code:#{code}"

    Server.get(:cache_vat_rates, key, fn _key ->
      case Repo.get_by(CyberCore.Accounting.VatRate, code: code, is_active: true) do
        nil -> {:error, :not_found}
        rate -> {:ok, rate}
      end
    end)
  end

  @doc """
  Взима всички ДДС ставки.
  """
  def list_vat_rates do
    case Server.get_all(:cache_vat_rates) do
      [] ->
        rates =
          CyberCore.Accounting.VatRate
          |> where([v], v.is_active == true)
          |> order_by([v], desc: v.rate)
          |> Repo.all()

        for rate <- rates do
          Server.put(:cache_vat_rates, rate.id, rate)
        end

        rates

      cached ->
        cached
        |> Enum.map(fn {_key, value} -> value end)
        |> Enum.uniq_by(& &1.id)
    end
  end

  @doc """
  Инвалидира кеша на ДДС ставките.
  """
  def invalidate_vat_rates do
    Server.invalidate_table(:cache_vat_rates)
    broadcast_invalidation(:cache_vat_rates)
  end

  # CN Nomenclature

  @doc """
  Взима КН код по ID.
  """
  def get_cn_code(id) when is_integer(id) do
    Server.get(:cache_nomenclatures, id, fn id ->
      case Inventory.get_cn_nomenclature(id) do
        nil -> {:error, :not_found}
        cn -> {:ok, cn}
      end
    end)
  end

  @doc """
  Взима КН код по код и година.
  """
  def get_cn_code(code, year \\ current_year()) do
    key = "cn:#{year}:#{code}"

    Server.get(:cache_nomenclatures, key, fn _key ->
      case Inventory.get_cn_nomenclature_by_code(code, year) do
        nil -> {:error, :not_found}
        cn -> {:ok, cn}
      end
    end)
  end

  @doc """
  Търси КН кодове по префикс (напр. "0101" ще намери всички кодове започващи с 0101).
  """
  def search_cn_codes(prefix, year \\ current_year(), limit \\ 20) do
    # За търсене не използваме кеш, защото комбинациите са много
    Inventory.search_cn_nomenclature(prefix, year, limit)
  end

  @doc """
  Инвалидира кеша на номенклатурите.
  """
  def invalidate_nomenclatures do
    Server.invalidate_table(:cache_nomenclatures)
    broadcast_invalidation(:cache_nomenclatures)
  end

  # Accounts

  @doc """
  Взима сметка по ID.
  """
  def get_account(id) do
    Server.get(:cache_accounts, id, fn id ->
      case Accounting.get_account(id) do
        nil -> {:error, :not_found}
        account -> {:ok, account}
      end
    end)
  end

  @doc """
  Взима сметка по код (напр. "411", "501").
  """
  def get_account_by_code(code) do
    key = "code:#{code}"

    Server.get(:cache_accounts, key, fn _key ->
      case Repo.get_by(CyberCore.Accounting.Account, code: code) do
        nil -> {:error, :not_found}
        account -> {:ok, account}
      end
    end)
  end

  @doc """
  Инвалидира кеша на сметките.
  """
  def invalidate_accounts do
    Server.invalidate_table(:cache_accounts)
    broadcast_invalidation(:cache_accounts)
  end

  # Settings

  @doc """
  Взима системна настройка по ключ.
  """
  def get_setting(key) do
    Server.get(:cache_settings, key, fn _key ->
      # Тук трябва да имате функция за settings
      # Засега return-ваме {:error, :not_found}
      {:error, :not_found}
    end)
  end

  @doc """
  Задава системна настройка.
  """
  def put_setting(key, value) do
    Server.put(:cache_settings, key, value)
    broadcast_invalidation(:cache_settings, key)
  end

  @doc """
  Инвалидира кеша на настройките.
  """
  def invalidate_settings do
    Server.invalidate_table(:cache_settings)
    broadcast_invalidation(:cache_settings)
  end

  # General Cache Operations

  @doc """
  Инвалидира всички кеш таблици.
  """
  def invalidate_all do
    Server.invalidate_all()
    Phoenix.PubSub.broadcast(CyberCore.PubSub, "cache:invalidate", {:invalidate_all})
  end

  @doc """
  Презарежда конкретна таблица от базата.
  """
  def reload(table) do
    Server.reload(table)
  end

  @doc """
  Връща статистика за използването на кеша.
  """
  def stats do
    Server.stats()
  end

  @doc """
  Взима размера на конкретна кеш таблица.
  """
  def size(table) do
    info = :ets.info(table)
    info[:size]
  end

  @doc """
  Проверява дали кешът работи правилно.
  """
  def health_check do
    try do
      stats = stats()
      %{status: :healthy, stats: stats}
    rescue
      _ ->
        %{status: :unhealthy, error: "Cache server not responding"}
    end
  end

  # Private Functions

  defp broadcast_invalidation(table) do
    Phoenix.PubSub.broadcast(CyberCore.PubSub, "cache:invalidate", {:invalidate_table, table})
  end

  defp broadcast_invalidation(table, key) do
    Phoenix.PubSub.broadcast(CyberCore.PubSub, "cache:invalidate", {:invalidate, table, key})
  end

  defp current_year do
    Date.utc_today().year
  end
end
