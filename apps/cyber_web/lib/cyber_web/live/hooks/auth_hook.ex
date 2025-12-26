defmodule CyberWeb.Live.Hooks.AuthHook do
  @moduledoc """
  LiveView hook за зареждане на текущия потребител от сесията.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias CyberCore.Accounts

  def on_mount(:default, _params, session, socket) do
    # Взимаме user_id от сесията
    case session["user_id"] do
      nil ->
        # Няма логнат потребител - редирект към login
        socket =
          socket
          |> put_flash(:error, "Моля, влезте в системата")
          |> redirect(to: "/login")

        {:halt, socket}

      user_id ->
        # Зареждаме потребителя от базата
        tenant_id = session["tenant_id"] || 1

        case Accounts.get_user(tenant_id, user_id) do
          nil ->
            # Потребителят не съществува - редирект към login
            socket =
              socket
              |> put_flash(:error, "Невалидна сесия")
              |> redirect(to: "/login")

            {:halt, socket}

          user ->
            # Зареждаме tenant и всички tenants за dropdown
            tenant = Accounts.get_tenant(tenant_id)
            tenants = Accounts.list_tenants()

            if tenant do
              {:cont,
               socket
               |> assign(:current_user, user)
               |> assign(:current_tenant, tenant)
               |> assign(:current_tenant_id, tenant.id)
               |> assign(:tenants, tenants)}
            else
              socket =
                socket
                |> put_flash(:error, "Фирмата не е намерена.")
                |> redirect(to: "/login")

              {:halt, socket}
            end
        end
    end
  end

  # За login страницата не искаме да редиректваме
  def on_mount(:allow_not_authenticated, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:cont, assign(socket, :current_user, nil)}

      user_id ->
        user = Accounts.get_user(session["tenant_id"], user_id)
        {:cont, assign(socket, :current_user, user)}
    end
  end
end
