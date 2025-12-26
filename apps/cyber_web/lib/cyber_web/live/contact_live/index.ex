defmodule CyberWeb.ContactLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Contacts
  alias CyberCore.Contacts.Contact
  alias Phoenix.LiveView.JS

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Контакти")
     |> assign(:tenant_id, @tenant_id)
     |> assign(:contacts, [])
     |> assign(:filter_type, "all")
     |> assign(:search_query, "")
     |> load_contacts()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Контакти")
    |> assign(:contact, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов контакт")
    |> assign(:contact, %Contact{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    contact = Contacts.get_contact!(@tenant_id, id)

    socket
    |> assign(:page_title, "Редактиране на контакт")
    |> assign(:contact, contact)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(@tenant_id, id)

    case Contacts.delete_contact(contact) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Контактът беше изтрит успешно")
         |> load_contacts()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при изтриване на контакта")}
    end
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> load_contacts()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_contacts()}
  end

  defp load_contacts(socket) do
    opts = build_filter_opts(socket)
    contacts = Contacts.list_contacts(@tenant_id, opts)
    assign(socket, :contacts, contacts)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:is_company, filter_value(socket.assigns.filter_type))
    |> maybe_put(:search, socket.assigns.search_query)
  end

  defp filter_value("all"), do: nil
  defp filter_value("company"), do: true
  defp filter_value("person"), do: false
  defp filter_value(_), do: nil

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <.flash_group flash={@flash} />

      <!-- Page Header -->
      <div class="mb-8">
        <div class="sm:flex sm:items-center sm:justify-between">
          <div>
            <h1 class="text-3xl font-bold text-zinc-900">Контакти</h1>
            <p class="mt-2 text-sm text-zinc-600">Управление на клиенти и доставчици</p>
          </div>
          <div class="mt-4 sm:mt-0">
            <.link
              patch={~p"/contacts/new"}
              class="inline-flex items-center gap-2 rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Нов контакт
            </.link>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div class="mb-6 flex gap-4">
        <div class="flex gap-2">
          <button
            phx-click="filter_type"
            phx-value-type="all"
            class={[
              "rounded-lg px-3 py-2 text-sm font-medium",
              if(@filter_type == "all", do: "bg-zinc-900 text-white", else: "bg-white text-zinc-700 hover:bg-zinc-50")
            ]}
          >
            Всички
          </button>
          <button
            phx-click="filter_type"
            phx-value-type="company"
            class={[
              "rounded-lg px-3 py-2 text-sm font-medium",
              if(@filter_type == "company", do: "bg-zinc-900 text-white", else: "bg-white text-zinc-700 hover:bg-zinc-50")
            ]}
          >
            Фирми
          </button>
          <button
            phx-click="filter_type"
            phx-value-type="person"
            class={[
              "rounded-lg px-3 py-2 text-sm font-medium",
              if(@filter_type == "person", do: "bg-zinc-900 text-white", else: "bg-white text-zinc-700 hover:bg-zinc-50")
            ]}
          >
            Физически лица
          </button>
        </div>

        <div class="flex-1">
          <form phx-change="search" class="flex">
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Търсене..."
              class="block w-full rounded-lg border-zinc-300 shadow-sm focus:border-zinc-900 focus:ring-zinc-900 sm:text-sm"
            />
          </form>
        </div>
      </div>

      <!-- Contacts Table -->
      <div class="overflow-hidden bg-white shadow sm:rounded-lg">
        <table class="min-w-full divide-y divide-zinc-200">
          <thead class="bg-zinc-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Име</th>
              <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Тип</th>
              <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Email</th>
              <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Телефон</th>
              <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-zinc-500">Град</th>
              <th class="relative px-6 py-3">
                <span class="sr-only">Действия</span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-200 bg-white">
            <%= for contact <- @contacts do %>
              <tr class="hover:bg-zinc-50">
                <td class="whitespace-nowrap px-6 py-4">
                  <div class="text-sm font-medium text-zinc-900"><%= contact.name %></div>
                  <%= if contact.company do %>
                    <div class="text-sm text-zinc-500"><%= contact.company %></div>
                  <% end %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  <%= if contact.is_company, do: "Фирма", else: "Физическо лице" %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  <%= contact.email %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  <%= contact.phone %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-zinc-500">
                  <%= contact.city %>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-right text-sm font-medium">
                  <div class="flex justify-end gap-3">
                    <.link patch={~p"/contacts/#{contact.id}/edit"} class="text-indigo-600 hover:text-indigo-900">
                      Редактирай
                    </.link>
                    <.link
                      phx-click={JS.push("delete", value: %{id: contact.id})}
                      data-confirm="Сигурни ли сте?"
                      class="text-red-600 hover:text-red-900"
                    >
                      Изтрий
                    </.link>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <%= if @live_action in [:new, :edit] do %>
      <.modal id="contact-modal" show on_cancel={JS.patch(~p"/contacts")}>
        <.live_component
          module={CyberWeb.ContactLive.FormComponent}
          id={@contact.id || :new}
          title={@page_title}
          action={@live_action}
          contact={@contact}
          tenant_id={@tenant_id}
          patch={~p"/contacts"}
        />
      </.modal>
    <% end %>
    """
  end
end
