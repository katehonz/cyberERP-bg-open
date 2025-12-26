defmodule CyberWeb.AccountLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting
  import CyberWeb.CoreComponents

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tenant_id, @tenant_id)
     |> assign(:search, "")
     |> assign(:filter_type, "")
     |> assign(:filter_class, "")
     |> assign(:show_import_modal, false)
     |> assign(:import_error, nil)
     |> assign(:import_success, nil)
     |> allow_upload(:xml_file, accept: ~w(.xml), max_entries: 1, max_file_size: 5_000_000)
     |> stream(:accounts, Accounting.list_accounts(@tenant_id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:tenant_id, @tenant_id)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Account")
    |> assign(:account, Accounting.get_account!(@tenant_id, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Account")
    |> assign(:account, %CyberCore.Accounting.Account{})
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    account = Accounting.get_account!(@tenant_id, id)
    {:ok, _} = Accounting.delete_account(account)

    {:noreply, stream_delete(socket, :accounts, account)}
  end

  @impl true
  def handle_info({CyberWeb.AccountLive.FormComponent, {:saved, account}}, socket) do
    {:noreply, stream_insert(socket, :accounts, account)}
  end

  # Export chart of accounts as XML
  @impl true
  def handle_event("export_xml", _params, socket) do
    case Accounting.export_chart_of_accounts(socket.assigns.tenant_id) do
      {:ok, xml_content} ->
        {:noreply,
         socket
         |> push_event("download", %{
           content: xml_content,
           filename: "smetkplan_#{Date.utc_today()}.xml",
           content_type: "application/xml"
         })}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Грешка при експортиране на сметкоплана")}
    end
  end

  # Show import modal
  def handle_event("show_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, true)}
  end

  # Hide import modal
  def handle_event("hide_import_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_import_modal, false)
     |> assign(:import_error, nil)
     |> assign(:import_success, nil)}
  end

  # Handle file upload and import
  def handle_event("import_xml", %{"replace" => replace}, socket) do
    replace_existing = replace == "true"

    uploaded_files =
      consume_uploaded_entries(socket, :xml_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case uploaded_files do
      [xml_content] ->
        opts = if replace_existing, do: [replace: true], else: [skip_existing: true]

        case Accounting.import_chart_of_accounts(socket.assigns.tenant_id, xml_content, opts) do
          {:ok, %{imported: imported, total: total}} ->
            {:noreply,
             socket
             |> assign(:import_success, "Успешно импортирани #{imported} от #{total} сметки")
             |> assign(:import_error, nil)
             |> stream(:accounts, Accounting.list_accounts(socket.assigns.tenant_id), reset: true)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:import_error, "Грешка при импортиране: #{inspect(reason)}")
             |> assign(:import_success, nil)}
        end

      [] ->
        {:noreply, assign(socket, :import_error, "Моля, изберете XML файл")}
    end
  end

  # Validate uploaded file
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  # Search and filter
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> filter_accounts()}
  end

  def handle_event("filter", %{"type" => type, "class" => class}, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> assign(:filter_class, class)
     |> filter_accounts()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:filter_type, "")
     |> assign(:filter_class, "")
     |> stream(:accounts, Accounting.list_accounts(socket.assigns.tenant_id), reset: true)}
  end

  defp filter_accounts(socket) do
    accounts = Accounting.list_accounts(socket.assigns.tenant_id)

    filtered =
      accounts
      |> filter_by_search(socket.assigns.search)
      |> filter_by_type(socket.assigns.filter_type)
      |> filter_by_class(socket.assigns.filter_class)

    stream(socket, :accounts, filtered, reset: true)
  end

  defp filter_by_search(accounts, ""), do: accounts
  defp filter_by_search(accounts, search) do
    search_lower = String.downcase(search)
    Enum.filter(accounts, fn account ->
      String.contains?(String.downcase(account.code || ""), search_lower) ||
      String.contains?(String.downcase(account.name || ""), search_lower) ||
      String.contains?(String.downcase(account.standard_code || ""), search_lower)
    end)
  end

  defp filter_by_type(accounts, ""), do: accounts
  defp filter_by_type(accounts, type) do
    type_atom = String.to_existing_atom(type)
    Enum.filter(accounts, fn account -> account.account_type == type_atom end)
  end

  defp filter_by_class(accounts, ""), do: accounts
  defp filter_by_class(accounts, class) do
    class_int = String.to_integer(class)
    Enum.filter(accounts, fn account -> account.account_class == class_int end)
  end

  defp format_account_type(:asset), do: "Актив"
  defp format_account_type(:liability), do: "Пасив"
  defp format_account_type(:equity), do: "Капитал"
  defp format_account_type(:revenue), do: "Приход"
  defp format_account_type(:expense), do: "Разход"
  defp format_account_type(nil), do: "-"
  defp format_account_type(_), do: "-"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Сметкоплан</h1>
          <p class="mt-1 text-sm text-gray-600">
            Управление на сметкоплана
          </p>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="export_xml"
            class="inline-flex items-center justify-center rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-green-700"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Експорт XML
          </button>
          <button
            phx-click="show_import_modal"
            class="inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
            </svg>
            Импорт XML
          </button>
          <.link
            patch={~p"/accounts/new"}
            class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Нова сметка
          </.link>
        </div>
      </div>

      <!-- Търсачка и филтри -->
      <div class="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
        <div class="flex flex-col gap-4 md:flex-row md:items-end">
          <!-- Търсене -->
          <div class="flex-1">
            <label class="block text-sm font-medium text-gray-700 mb-1">Търсене</label>
            <form phx-change="search" phx-submit="search">
              <div class="relative">
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Търси по код, име..."
                  phx-debounce="300"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm pl-10"
                />
                <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                  <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
              </div>
            </form>
          </div>

          <!-- Филтър по тип -->
          <div class="w-full md:w-48">
            <label class="block text-sm font-medium text-gray-700 mb-1">Тип сметка</label>
            <form phx-change="filter">
              <input type="hidden" name="class" value={@filter_class} />
              <select
                name="type"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Всички типове</option>
                <option value="asset" selected={@filter_type == "asset"}>Актив</option>
                <option value="liability" selected={@filter_type == "liability"}>Пасив</option>
                <option value="equity" selected={@filter_type == "equity"}>Капитал</option>
                <option value="revenue" selected={@filter_type == "revenue"}>Приход</option>
                <option value="expense" selected={@filter_type == "expense"}>Разход</option>
              </select>
            </form>
          </div>

          <!-- Филтър по клас -->
          <div class="w-full md:w-48">
            <label class="block text-sm font-medium text-gray-700 mb-1">Клас</label>
            <form phx-change="filter">
              <input type="hidden" name="type" value={@filter_type} />
              <select
                name="class"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Всички класове</option>
                <option value="1" selected={@filter_class == "1"}>1 - Капитал</option>
                <option value="2" selected={@filter_class == "2"}>2 - Дълготрайни активи</option>
                <option value="3" selected={@filter_class == "3"}>3 - Материални запаси</option>
                <option value="4" selected={@filter_class == "4"}>4 - Разчети</option>
                <option value="5" selected={@filter_class == "5"}>5 - Парични средства</option>
                <option value="6" selected={@filter_class == "6"}>6 - Разходи</option>
                <option value="7" selected={@filter_class == "7"}>7 - Приходи</option>
                <option value="9" selected={@filter_class == "9"}>9 - Задбалансови</option>
              </select>
            </form>
          </div>

          <!-- Изчистване -->
          <div>
            <button
              :if={@search != "" or @filter_type != "" or @filter_class != ""}
              phx-click="clear_filters"
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
              Изчисти
            </button>
          </div>
        </div>
      </div>

      <!-- Таблица -->
      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Име
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Код
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Стандартен код
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Тип
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Клас
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Действия
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for {_id, account} <- @streams.accounts do %>
              <tr class="hover:bg-gray-50" id={"accounts-#{account.id}"}>
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= account.name %>
                </td>
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= account.code %>
                </td>
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= account.standard_code %>
                </td>
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= format_account_type(account.account_type) %>
                </td>
                <td class="px-4 py-3 text-sm text-gray-500">
                  <%= account.account_class %>
                </td>
                <td class="px-4 py-3 text-right text-sm">
                  <.link
                    patch={~p"/accounts/#{account}/edit"}
                    class="text-indigo-600 hover:text-indigo-700 mr-3"
                  >
                    Редакция
                  </.link>
                  <.link
                    phx-click="delete"
                    phx-value-id={account.id}
                    data-confirm="Сигурни ли сте?"
                    class="text-red-600 hover:text-red-700 cursor-pointer"
                  >
                    Изтриване
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if @streams.accounts == [] do %>
          <div class="text-center py-12">
            <div class="mx-auto h-12 w-12 text-gray-400 text-4xl">💼</div>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Няма сметки</h3>
            <p class="mt-1 text-sm text-gray-500">
              Започнете като създадете нова сметка.
            </p>
            <div class="mt-6">
              <.link
                patch={~p"/accounts/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
              >
                + Нова сметка
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="account-modal"
      show
      on_cancel={~p"/accounts"}
    >
      <.live_component
        module={CyberWeb.AccountLive.FormComponent}
        id={@account.id || :new}
        title={@page_title}
        action={@live_action}
        account={@account}
        tenant_id={@tenant_id}
        navigate={~p"/accounts"}
      />
    </.modal>

    <!-- Import Modal -->
    <.modal
      :if={@show_import_modal}
      id="import-modal"
      show
      on_cancel={JS.push("hide_import_modal")}
    >
      <div class="p-4">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Импорт на сметкоплан от XML</h3>

        <%= if @import_success do %>
          <div class="mb-4 p-4 bg-green-50 border border-green-200 rounded-md">
            <p class="text-green-800"><%= @import_success %></p>
          </div>
        <% end %>

        <%= if @import_error do %>
          <div class="mb-4 p-4 bg-red-50 border border-red-200 rounded-md">
            <p class="text-red-800"><%= @import_error %></p>
          </div>
        <% end %>

        <form phx-submit="import_xml" phx-change="validate_upload" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">XML файл</label>
            <.live_file_input upload={@uploads.xml_file} class="block w-full text-sm text-gray-500
              file:mr-4 file:py-2 file:px-4
              file:rounded-md file:border-0
              file:text-sm file:font-semibold
              file:bg-indigo-50 file:text-indigo-700
              hover:file:bg-indigo-100" />

            <%= for entry <- @uploads.xml_file.entries do %>
              <div class="mt-2 text-sm text-gray-600">
                <%= entry.client_name %> (<%= Float.round(entry.client_size / 1024, 1) %> KB)
              </div>
              <%= for err <- upload_errors(@uploads.xml_file, entry) do %>
                <p class="text-red-500 text-sm"><%= err %></p>
              <% end %>
            <% end %>
          </div>

          <div>
            <label class="flex items-center">
              <input type="checkbox" name="replace" value="true" class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50">
              <span class="ml-2 text-sm text-gray-600">Замени съществуващите сметки (изтрива всички текущи сметки!)</span>
            </label>
          </div>

          <div class="flex justify-end gap-3 mt-6">
            <button
              type="button"
              phx-click="hide_import_modal"
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Отказ
            </button>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-transparent rounded-md hover:bg-indigo-700"
            >
              Импортирай
            </button>
          </div>
        </form>
      </div>
    </.modal>
    """
  end
end
