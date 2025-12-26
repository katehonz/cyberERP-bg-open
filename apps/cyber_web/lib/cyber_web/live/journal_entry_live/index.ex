defmodule CyberWeb.JournalEntryLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting

  @impl true
  def mount(_params, _session, socket) do
    # TODO: Get from session
    tenant_id = 1

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:page_title, "Счетоводни записи")
      |> assign(:show_posted, :all)
      |> load_entries()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Счетоводни записи")
    |> assign(:journal_entry, nil)
    |> assign(:show_form, false)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов запис")
    |> assign(:journal_entry, nil)
    |> assign(:show_form, true)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    entry =
      Accounting.get_journal_entry!(socket.assigns.tenant_id, String.to_integer(id), [:lines])

    socket
    |> assign(:page_title, "Преглед на запис")
    |> assign(:journal_entry, entry)
    |> assign(:show_form, false)
  end

  @impl true
  def handle_info({:entry_created, message}, socket) do
    socket =
      socket
      |> put_flash(:info, message)
      |> push_navigate(to: ~p"/journal-entries")
      |> load_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_posted", %{"show" => show}, socket) do
    show_atom = String.to_existing_atom(show)

    socket =
      socket
      |> assign(:show_posted, show_atom)
      |> load_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("post_entry", %{"id" => id}, socket) do
    entry = Accounting.get_journal_entry!(socket.assigns.tenant_id, String.to_integer(id))

    case Accounting.post_journal_entry(entry) do
      {:ok, _posted_entry} ->
        socket =
          socket
          |> put_flash(:info, "Записът е успешно постнат")
          |> load_entries()

        {:noreply, socket}

      {:error, :unbalanced_entry} ->
        {:noreply, put_flash(socket, :error, "Записът не е балансиран (Дебит ≠ Кредит)")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка при постинг: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    entry = Accounting.get_journal_entry!(socket.assigns.tenant_id, String.to_integer(id))

    case Accounting.delete_journal_entry(entry) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Записът е изтрит")
          |> load_entries()

        {:noreply, socket}

      {:error, :entry_already_posted} ->
        {:noreply, put_flash(socket, :error, "Не може да се изтрие постнат запис")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при изтриване")}
    end
  end

  defp load_entries(socket) do
    filters =
      case socket.assigns.show_posted do
        :all -> []
        :posted -> [is_posted: true]
        :draft -> [is_posted: false]
      end

    entries = Accounting.list_journal_entries(socket.assigns.tenant_id, filters)
    assign(socket, :entries, entries)
  end

  defp format_date(nil), do: "-"
  defp format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp format_amount(nil), do: "0.00"
  defp format_amount(amount), do: Decimal.to_string(amount, :normal)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Счетоводни записи</h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички счетоводни записи в системата
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate={~p"/journal-entries/new"}
            class="block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Нов запис
          </.link>
        </div>
      </div>

      <div class="mt-4 flex items-center space-x-4">
        <label class="text-sm font-medium text-gray-700">Филтър:</label>
        <select
          phx-change="filter_posted"
          name="show"
          class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        >
          <option value="all" selected={@show_posted == :all}>Всички</option>
          <option value="draft" selected={@show_posted == :draft}>Чернови</option>
          <option value="posted" selected={@show_posted == :posted}>Постнати</option>
        </select>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Номер
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Дата
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Описание
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Сума
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                      Статус
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Действия</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for entry <- @entries do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= entry.entry_number || "-" %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= format_date(entry.document_date) %>
                      </td>
                      <td class="px-3 py-4 text-sm text-gray-500">
                        <%= entry.description %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= format_amount(entry.total_amount) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-center">
                        <%= if entry.is_posted do %>
                          <span class="inline-flex rounded-full bg-green-100 px-2 text-xs font-semibold leading-5 text-green-800">
                            Постнат
                          </span>
                        <% else %>
                          <span class="inline-flex rounded-full bg-yellow-100 px-2 text-xs font-semibold leading-5 text-yellow-800">
                            Чернова
                          </span>
                        <% end %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <.link
                          navigate={~p"/journal-entries/#{entry.id}"}
                          class="text-indigo-600 hover:text-indigo-900 mr-4"
                        >
                          Преглед
                        </.link>

                        <%= if not entry.is_posted do %>
                          <button
                            type="button"
                            phx-click="post_entry"
                            phx-value-id={entry.id}
                            data-confirm="Сигурни ли сте, че искате да постнете този запис?"
                            class="text-green-600 hover:text-green-900 mr-4"
                          >
                            Постинг
                          </button>

                          <button
                            type="button"
                            phx-click="delete_entry"
                            phx-value-id={entry.id}
                            data-confirm="Сигурни ли сте, че искате да изтриете този запис?"
                            class="text-red-600 hover:text-red-900"
                          >
                            Изтрий
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <%= if @show_form do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-screen items-center justify-center px-4">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

            <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-5xl sm:p-6">
              <.live_component
                module={CyberWeb.JournalEntryLive.FormComponent}
                id="journal-entry-form"
                title="Нов счетоводен запис"
                tenant_id={@tenant_id}
              />
            </div>
          </div>
        </div>
      <% end %>

      <%= if @journal_entry do %>
        <div class="fixed inset-0 z-50 overflow-y-auto" phx-click="close_modal">
          <div class="flex min-h-screen items-center justify-center px-4">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

            <div
              class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl sm:p-6"
              phx-click="prevent_close"
            >
              <div class="absolute right-0 top-0 pr-4 pt-4">
                <.link navigate={~p"/journal-entries"} class="text-gray-400 hover:text-gray-500">
                  <span class="sr-only">Затвори</span>
                  <svg
                    class="h-6 w-6"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </.link>
              </div>

              <div class="sm:flex sm:items-start">
                <div class="w-full mt-3 text-center sm:mt-0 sm:text-left">
                  <h3 class="text-lg font-semibold leading-6 text-gray-900 mb-4">
                    Запис <%= @journal_entry.entry_number || "без номер" %>
                  </h3>

                  <div class="grid grid-cols-3 gap-4 mb-6">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Док. дата</label>
                      <p class="mt-1 text-sm text-gray-900">
                        <%= format_date(@journal_entry.document_date) %>
                      </p>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">ДДС дата</label>
                      <p class="mt-1 text-sm text-gray-900">
                        <%= format_date(@journal_entry.vat_date) %>
                      </p>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Счет. дата</label>
                      <p class="mt-1 text-sm text-gray-900">
                        <%= format_date(@journal_entry.accounting_date) %>
                      </p>
                    </div>
                  </div>

                  <div class="mb-6">
                    <label class="block text-sm font-medium text-gray-700">Описание</label>
                    <p class="mt-1 text-sm text-gray-900"><%= @journal_entry.description %></p>
                  </div>

                  <div class="mb-4">
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Редове:</h4>
                    <table class="min-w-full divide-y divide-gray-300">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500">
                            Сметка
                          </th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500">
                            Дебит
                          </th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500">
                            Кредит
                          </th>
                          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500">
                            Описание
                          </th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-200 bg-white">
                        <%= for line <- @journal_entry.lines do %>
                          <tr>
                            <td class="px-3 py-2 text-sm text-gray-900">
                              <%= if line.account do %>
                                <%= line.account.code %> - <%= line.account.name %>
                              <% else %>
                                Сметка #<%= line.account_id %>
                              <% end %>
                            </td>
                            <td class="px-3 py-2 text-sm text-gray-900 text-right font-mono">
                              <%= format_amount(line.debit_amount) %>
                            </td>
                            <td class="px-3 py-2 text-sm text-gray-900 text-right font-mono">
                              <%= format_amount(line.credit_amount) %>
                            </td>
                            <td class="px-3 py-2 text-sm text-gray-500">
                              <%= line.description %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>

                  <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                    <.link
                      navigate={~p"/journal-entries"}
                      class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
                    >
                      Затвори
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
