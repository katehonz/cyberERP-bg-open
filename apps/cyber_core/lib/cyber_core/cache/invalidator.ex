defmodule CyberCore.Cache.Invalidator do
  @moduledoc """
  Автоматично инвалидиране на кеш при промяна на данни.

  Този модул се използва в контекстите за автоматично изчистване на кеша
  след CRUD операции върху кеширани данни.

  ## Използване в контексти

  ### Пример 1: След създаване/обновяване на мерна единица

      def create_measurement_unit(attrs) do
        %MeasurementUnit{}
        |> MeasurementUnit.changeset(attrs)
        |> Repo.insert()
        |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_units/1)
      end

      def update_measurement_unit(%MeasurementUnit{} = unit, attrs) do
        unit
        |> MeasurementUnit.changeset(attrs)
        |> Repo.update()
        |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_units/1)
      end

  ### Пример 2: След създаване/обновяване на ДДС ставка

      def create_vat_rate(attrs) do
        %VatRate{}
        |> VatRate.changeset(attrs)
        |> Repo.insert()
        |> tap(&CyberCore.Cache.Invalidator.invalidate_vat_rates/1)
      end

  ### Пример 3: В Ecto.Multi транзакции

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:account, changeset)
      |> Ecto.Multi.run(:invalidate_cache, fn _repo, %{account: account} ->
        CyberCore.Cache.Invalidator.invalidate_account(account)
        {:ok, account}
      end)
      |> Repo.transaction()

  ### Пример 4: Broadcast invalidation при bulk операции

      def import_cn_codes(codes) do
        Repo.transaction(fn ->
          # Bulk insert
          Repo.insert_all(CnNomenclature, codes)
          # Invalidate entire table
          CyberCore.Cache.Invalidator.invalidate_nomenclatures()
        end)
      end
  """

  require Logger
  alias CyberCore.Cache

  # Measurement Units

  @doc """
  Инвалидира кеша за конкретна мерна единица.
  """
  def invalidate_measurement_unit({:ok, %{id: id} = unit}) do
    Cache.Server.invalidate(:cache_measurement_units, id)

    if unit.code do
      Cache.Server.invalidate(:cache_measurement_units, "code:#{unit.code}")
    end

    broadcast(:measurement_unit_changed, %{id: id})
    Logger.debug("Cache invalidated: measurement_unit #{id}")
    {:ok, unit}
  end

  def invalidate_measurement_unit({:error, _} = error), do: error

  def invalidate_measurement_unit(%{id: id} = unit) do
    invalidate_measurement_unit({:ok, unit})
    unit
  end

  @doc """
  Инвалидира целия кеш за мерни единици.
  """
  def invalidate_measurement_units(result \\ nil) do
    Cache.invalidate_measurement_units()
    Logger.debug("Cache invalidated: all measurement_units")
    result
  end

  # VAT Rates

  @doc """
  Инвалидира кеша за конкретна ДДС ставка.
  """
  def invalidate_vat_rate({:ok, %{id: id} = rate}) do
    Cache.Server.invalidate(:cache_vat_rates, id)

    if rate.code do
      Cache.Server.invalidate(:cache_vat_rates, "code:#{rate.code}")
    end

    broadcast(:vat_rate_changed, %{id: id})
    Logger.debug("Cache invalidated: vat_rate #{id}")
    {:ok, rate}
  end

  def invalidate_vat_rate({:error, _} = error), do: error

  def invalidate_vat_rate(%{id: id} = rate) do
    invalidate_vat_rate({:ok, rate})
    rate
  end

  @doc """
  Инвалидира целия кеш за ДДС ставки.
  """
  def invalidate_vat_rates(result \\ nil) do
    Cache.invalidate_vat_rates()
    Logger.debug("Cache invalidated: all vat_rates")
    result
  end

  # CN Nomenclature

  @doc """
  Инвалидира кеша за конкретна номенклатура.
  """
  def invalidate_cn_code({:ok, %{id: id} = cn}) do
    Cache.Server.invalidate(:cache_nomenclatures, id)

    if cn.code && cn.year do
      Cache.Server.invalidate(:cache_nomenclatures, "cn:#{cn.year}:#{cn.code}")
    end

    broadcast(:cn_code_changed, %{id: id})
    Logger.debug("Cache invalidated: cn_code #{id}")
    {:ok, cn}
  end

  def invalidate_cn_code({:error, _} = error), do: error

  def invalidate_cn_code(%{id: id} = cn) do
    invalidate_cn_code({:ok, cn})
    cn
  end

  @doc """
  Инвалидира целия кеш за номенклатури.
  """
  def invalidate_nomenclatures(result \\ nil) do
    Cache.invalidate_nomenclatures()
    Logger.debug("Cache invalidated: all nomenclatures")
    result
  end

  # Accounts

  @doc """
  Инвалидира кеша за конкретна сметка.
  """
  def invalidate_account({:ok, %{id: id} = account}) do
    Cache.Server.invalidate(:cache_accounts, id)

    if account.code do
      Cache.Server.invalidate(:cache_accounts, "code:#{account.code}")
    end

    broadcast(:account_changed, %{id: id})
    Logger.debug("Cache invalidated: account #{id}")
    {:ok, account}
  end

  def invalidate_account({:error, _} = error), do: error

  def invalidate_account(%{id: id} = account) do
    invalidate_account({:ok, account})
    account
  end

  @doc """
  Инвалидира целия кеш за сметки.
  """
  def invalidate_accounts(result \\ nil) do
    Cache.invalidate_accounts()
    Logger.debug("Cache invalidated: all accounts")
    result
  end

  # Generic invalidation

  @doc """
  Инвалидира всички кеш таблици.
  """
  def invalidate_all do
    Cache.invalidate_all()
    broadcast(:cache_cleared, %{})
    Logger.info("Cache invalidated: ALL")
  end

  # Private helpers

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(
      CyberCore.PubSub,
      "cache:events",
      {event, payload}
    )
  end
end
