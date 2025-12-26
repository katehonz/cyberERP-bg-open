defmodule CyberWeb.Live.Hooks.TenantHook do
  @moduledoc """
  LiveView hook за зареждане на активната фирма и списък с фирми.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias CyberCore.Accounts

  def on_mount(:default, _params, session, socket) do
    # Взимаме current_tenant_id от connect params (localStorage), session или използваме 1 по подразбиране
    requested_tenant_id =
      get_connect_params(socket)["tenant_id"] ||
        session["current_tenant_id"] ||
        1

    # Конвертираме към integer ако е string
    requested_tenant_id =
      case requested_tenant_id do
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
        _ -> 1
      end

    # Зареждаме всички фирми
    tenants = Accounts.list_tenants()

    # Опитваме да заредим текущата фирма или използваме първата налична
    current_tenant =
      case Accounts.get_tenant(requested_tenant_id) do
        nil ->
          # Ако няма фирма с исканото ID, вземаме първата налична
          case tenants do
            [] -> nil
            [first | _] -> first
          end

        tenant ->
          tenant
      end

    # Ако няма налични фирми, връщаме грешка
    if current_tenant == nil do
      raise "Няма налични фирми в системата. Моля, създайте поне една фирма."
    end

    {:cont,
     socket
     |> assign(:current_tenant_id, current_tenant.id)
     |> assign(:current_tenant, current_tenant)
     |> assign(:tenants, tenants)
     |> attach_hook(:handle_tenant_switch_info, :handle_info, &handle_tenant_switch_info/2)
     |> attach_hook(:handle_tenant_switch_event, :handle_event, &handle_tenant_switch_event/3)}
  end

  # Handle event от формата
  defp handle_tenant_switch_event("switch_tenant", %{"tenant_id" => tenant_id_str}, socket) do
    tenant_id = String.to_integer(tenant_id_str)
    tenant = Accounts.get_tenant!(tenant_id)

    {:halt,
     socket
     |> assign(:current_tenant_id, tenant_id)
     |> assign(:current_tenant, tenant)
     |> put_flash(:info, "Превключихте към #{tenant.name}")}
  end

  defp handle_tenant_switch_event(_, _params, socket), do: {:cont, socket}

  # Handle info съобщения
  defp handle_tenant_switch_info({:tenant_switched, tenant_id}, socket) do
    tenant = Accounts.get_tenant!(tenant_id)

    {:cont,
     socket
     |> assign(:current_tenant_id, tenant_id)
     |> assign(:current_tenant, tenant)
     |> put_flash(:info, "Превключихте към #{tenant.name}")}
  end

  defp handle_tenant_switch_info(_, socket), do: {:cont, socket}
end
