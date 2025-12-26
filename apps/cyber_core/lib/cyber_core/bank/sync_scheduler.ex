defmodule CyberCore.Bank.SyncScheduler do
  @moduledoc """
  Scheduled job за автоматична синхронизация на банкови транзакции.

  Периодично проверява всички активни банкови профили с включена
  автоматична синхронизация и импортира нови транзакции от Salt Edge.
  """

  use GenServer
  require Logger

  alias CyberCore.Repo
  alias CyberCore.Bank.{BankProfile, BankService}

  import Ecto.Query

  # Sync interval: every 4 hours
  @sync_interval :timer.hours(4)

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sync сега (ръчно задействане).
  """
  def sync_now do
    GenServer.cast(__MODULE__, :sync)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    # Schedule first sync after 1 minute
    schedule_sync(:timer.minutes(1))

    Logger.info("Bank sync scheduler started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync, state) do
    Logger.info("Starting scheduled bank sync...")
    perform_sync()

    # Schedule next sync
    schedule_sync(@sync_interval)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:sync, state) do
    Logger.info("Manual bank sync triggered...")
    perform_sync()

    {:noreply, state}
  end

  # Private Functions

  defp schedule_sync(interval) do
    Process.send_after(self(), :sync, interval)
  end

  defp perform_sync do
    # Намери всички активни профили с auto_sync_enabled
    profiles =
      BankProfile
      |> where([p], p.is_active == true)
      |> where([p], p.auto_sync_enabled == true)
      |> where([p], not is_nil(p.saltedge_connection_id))
      |> Repo.all()

    Logger.info("Found #{length(profiles)} profiles to sync")

    # Sync всеки профил
    Enum.each(profiles, fn profile ->
      sync_profile(profile)
    end)

    Logger.info("Scheduled bank sync completed")
  end

  defp sync_profile(profile) do
    Logger.info("Syncing profile #{profile.id} (#{profile.name})...")

    # Sync транзакции от последната синхронизация или последните 30 дни
    from_date =
      if profile.last_synced_at do
        profile.last_synced_at
        |> DateTime.to_date()
        |> Date.to_iso8601()
      else
        Date.add(Date.utc_today(), -30)
        |> Date.to_iso8601()
      end

    case BankService.sync_saltedge_transactions(profile.id, from_date: from_date) do
      {:ok, result} ->
        Logger.info(
          "Successfully synced #{length(result.transactions)} transactions for profile #{profile.id}"
        )

      {:error, error} ->
        Logger.error("Failed to sync profile #{profile.id}: #{inspect(error)}")
    end
  rescue
    error ->
      Logger.error("Exception while syncing profile #{profile.id}: #{Exception.message(error)}")
  end
end
