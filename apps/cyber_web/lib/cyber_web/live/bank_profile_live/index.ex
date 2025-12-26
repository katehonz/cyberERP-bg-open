defmodule CyberWeb.BankProfileLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Repo
  alias CyberCore.Bank.{BankProfile, BankService}

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Банкови профили")
     |> load_bank_profiles()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    profile =
      BankProfile
      |> where([p], p.id == ^id and p.tenant_id == ^socket.assigns.current_tenant_id)
      |> Repo.one!()
      |> Repo.preload([:bank_account, :buffer_account])

    socket
    |> assign(:page_title, "Редактиране на банков профил")
    |> assign(:bank_profile, profile)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов банков профил")
    |> assign(:bank_profile, %BankProfile{tenant_id: socket.assigns.current_tenant_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Банкови профили")
    |> assign(:bank_profile, nil)
  end

  @impl true
  def handle_info({CyberWeb.BankProfileLive.FormComponent, {:saved, _profile}}, socket) do
    {:noreply, load_bank_profiles(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    profile =
      BankProfile
      |> where([p], p.id == ^id and p.tenant_id == ^socket.assigns.current_tenant_id)
      |> Repo.one!()

    {:ok, _} = Repo.delete(profile)

    {:noreply,
     socket
     |> put_flash(:info, "Банковият профил беше изтрит")
     |> load_bank_profiles()}
  end

  @impl true
  def handle_event("sync_now", %{"id" => id}, socket) do
    case BankService.sync_saltedge_transactions(id) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Синхронизирани #{length(result.transactions)} транзакции")
         |> load_bank_profiles()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при синхронизация: #{inspect(reason)}")}
    end
  end

  defp load_bank_profiles(socket) do
    profiles =
      BankProfile
      |> where([p], p.tenant_id == ^socket.assigns.current_tenant_id)
      |> where([p], p.is_active == true)
      |> preload([:bank_account, :buffer_account, :bank_connection])
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()

    assign(socket, :bank_profiles, profiles)
  end
end
