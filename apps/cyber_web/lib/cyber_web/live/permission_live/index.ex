defmodule CyberWeb.PermissionLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Guardian

  @roles ~w(admin user observer)

  def mount(_params, _session, socket) do
    permissions = Guardian.list_permissions()

    role_permissions =
      for role <- @roles do
        {role, Guardian.get_role_permissions(role)}
      end
      |> Map.new()

    socket =
      assign(socket,
        permissions: permissions,
        roles: @roles,
        role_permissions: role_permissions,
        page_title: "Управление на права"
      )

    {:ok, socket}
  end

  def handle_event("update_permissions", %{"permissions" => form_data}, socket) do
    # This is a simple implementation. A more robust solution would be to
    # handle this in a dedicated context function.
    for role <- @roles do
      current_permissions = socket.assigns.role_permissions[role]
      form_permissions = Map.get(form_data, role, []) |> Map.keys()

      # Permissions to grant
      for p_to_grant <- form_permissions -- current_permissions do
        Guardian.grant(role, p_to_grant)
      end

      # Permissions to revoke
      for p_to_revoke <- current_permissions -- form_permissions do
        Guardian.revoke(role, p_to_revoke)
      end
    end

    role_permissions =
      for role <- @roles do
        {role, Guardian.get_role_permissions(role)}
      end
      |> Map.new()

    {:noreply,
     assign(socket, role_permissions: role_permissions, page_title: "Управление на права")}
  end

  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Управление на права</h1>
          <p class="mt-2 text-sm text-gray-700">
            Управление на права за достъп по роли
          </p>
        </div>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <.form for={%{}} phx-submit="update_permissions">
                <table class="min-w-full divide-y divide-gray-300">
                  <thead class="bg-gray-50">
                    <tr>
                      <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                        Права
                      </th>
                      <%= for role <- @roles do %>
                        <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                          <%= format_role(role) %>
                        </th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                    <%= for permission <- @permissions do %>
                      <tr>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                          <div class="font-medium text-gray-900"><%= permission.name %></div>
                          <div class="text-gray-500"><%= permission.description %></div>
                        </td>
                        <%= for role <- @roles do %>
                          <td class="whitespace-nowrap px-3 py-4 text-sm text-center">
                            <input
                              type="checkbox"
                              name={"permissions[#{role}][#{permission.name}]"}
                              value="true"
                              checked={permission.name in @role_permissions[role]}
                              class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                            />
                          </td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>

                <div class="bg-gray-50 px-4 py-3 text-right sm:px-6">
                  <button
                    type="submit"
                    class="inline-flex justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                  >
                    Запази промените
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_role("admin"), do: "Администратор"
  defp format_role("user"), do: "Потребител"
  defp format_role("observer"), do: "Наблюдател"
  defp format_role(role), do: String.capitalize(role)

  defp role_badge_class("admin"), do: "bg-purple-100 text-purple-800"
  defp role_badge_class("user"), do: "bg-blue-100 text-blue-800"
  defp role_badge_class("observer"), do: "bg-gray-100 text-gray-800"
  defp role_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp group_permissions(permissions) do
    permissions
    |> Enum.group_by(fn p ->
      p.name |> String.split(".") |> List.first()
    end)
    |> Enum.sort_by(fn {group, _} -> group end)
  end

  defp format_group("contacts"), do: "Контрагенти"
  defp format_group("products"), do: "Артикули"
  defp format_group("invoices"), do: "Фактури"
  defp format_group("purchases"), do: "Покупки"
  defp format_group("warehouse"), do: "Склад"
  defp format_group("accounting"), do: "Счетоводство"
  defp format_group("vat"), do: "ДДС"
  defp format_group("production"), do: "Производство"
  defp format_group("bank"), do: "Банки"
  defp format_group("reports"), do: "Справки"
  defp format_group("settings"), do: "Настройки"
  defp format_group("users"), do: "Потребители"
  defp format_group("assets"), do: "ДМА"
  defp format_group(group), do: String.capitalize(group)

  defp format_permission_name(name) do
    action = name |> String.split(".") |> List.last()

    case action do
      "create" -> "Създаване"
      "read" -> "Преглед"
      "update" -> "Редакция"
      "delete" -> "Изтриване"
      "export" -> "Експорт"
      "import" -> "Импорт"
      _ -> String.capitalize(action)
    end
  end
end
