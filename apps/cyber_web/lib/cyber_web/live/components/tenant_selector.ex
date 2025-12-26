defmodule CyberWeb.Components.TenantSelector do
  use CyberWeb, :live_component

  alias CyberCore.Accounts

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    tenants = Accounts.list_tenants()
    current_tenant_id = assigns[:current_tenant_id] || get_current_tenant_id(socket)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tenants, tenants)
     |> assign(:current_tenant_id, current_tenant_id)}
  end

  @impl true
  def handle_event("switch_tenant", %{"tenant_id" => tenant_id}, socket) do
    tenant_id = String.to_integer(tenant_id)

    # Съобщаваме на parent LiveView
    send(self(), {:tenant_switched, tenant_id})

    {:noreply, assign(socket, :current_tenant_id, tenant_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="border-b border-zinc-200 px-4 py-3">
      <label class="block text-xs font-semibold uppercase tracking-wide text-zinc-400 mb-2">
        Активна фирма
      </label>
      <select
        id="tenant-selector"
        phx-change="switch_tenant"
        phx-target={@myself}
        name="tenant_id"
        class="w-full rounded-lg border-zinc-300 text-sm focus:border-zinc-900 focus:ring-zinc-900"
      >
        <%= for tenant <- @tenants do %>
          <option value={tenant.id} selected={tenant.id == @current_tenant_id}>
            <%= tenant.name %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp get_current_tenant_id(_socket) do
    # TODO: Взимаме от session
    1
  end
end
