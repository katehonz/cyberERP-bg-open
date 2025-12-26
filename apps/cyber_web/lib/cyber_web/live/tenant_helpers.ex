defmodule CyberWeb.Live.TenantHelpers do
  @moduledoc """
  Помощни функции за работа с активна фирма в LiveView.
  """

  def handle_tenant_switch(%{"tenant_id" => tenant_id_str} = _params, socket) do
    tenant_id = String.to_integer(tenant_id_str)
    _tenant = CyberCore.Accounts.get_tenant!(tenant_id)

    # Изпращаме съобщение което ще бъде хванато от hook-а
    send(self(), {:tenant_switched, tenant_id})

    # Опционално: запазваме в session (ще се имплементира по-късно)
    # Phoenix.LiveView.put_session(socket, "current_tenant_id", tenant_id)

    {:noreply, socket}
  end
end
