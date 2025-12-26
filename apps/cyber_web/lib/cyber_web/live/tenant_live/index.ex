defmodule CyberWeb.TenantLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :tenants, Accounts.list_tenants())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Редактиране на фирма")
    |> assign(:tenant, Accounts.get_tenant!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нова фирма")
    |> assign(:tenant, %CyberCore.Accounts.Tenant{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Фирми")
    |> assign(:tenant, nil)
  end

  @impl true
  def handle_info({CyberWeb.TenantLive.FormComponent, {:saved, tenant}}, socket) do
    {:noreply, stream_insert(socket, :tenants, tenant)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tenant = Accounts.get_tenant!(id)
    {:ok, _} = Accounts.delete_tenant(tenant)

    {:noreply, stream_delete(socket, :tenants, tenant)}
  end

  @impl true
  def handle_event("set_active", %{"id" => id}, socket) do
    # Изпращаме JavaScript команда за запис в localStorage и reload
    {:noreply, push_event(socket, "set-active-tenant", %{tenant_id: id})}
  end
end
