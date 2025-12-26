defmodule CyberWeb.OpeningBalancesLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Accounting
  alias CyberCore.Contacts

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"] || 1

    {:ok,
     socket
     |> assign(:tenant_id, tenant_id)
     |> assign(:active_tab, :stock)
     |> assign(:search, "")
     |> load_data()}
  end

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id

    socket
    |> assign(:products, Inventory.list_products(tenant_id))
    |> assign(:products_with_balances, load_products_with_balances(tenant_id))
    |> assign(:warehouses, Inventory.list_warehouses(tenant_id))
    |> assign(:accounts, Accounting.list_accounts(tenant_id))
    |> assign(:accounts_with_balances, load_accounts_with_balances(tenant_id))
    |> assign(:contacts, Contacts.list_contacts(tenant_id))
    |> assign(:contacts_with_balances, load_contacts_with_balances(tenant_id))
  end

  defp load_products_with_balances(tenant_id) do
    try do
      Inventory.list_products_with_opening_balances(tenant_id)
    rescue
      _ -> []
    end
  end

  defp load_accounts_with_balances(tenant_id) do
    try do
      Accounting.list_accountsWithOpeningBalances(tenant_id)
    rescue
      _ -> []
    end
  end

  defp load_contacts_with_balances(tenant_id) do
    Contacts.list_contacts(tenant_id)
    |> Enum.filter(fn c ->
      (c.opening_debit_balance && Decimal.compare(c.opening_debit_balance, 0) != :eq) ||
      (c.opening_credit_balance && Decimal.compare(c.opening_credit_balance, 0) != :eq)
    end)
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    tab_atom = case tab do
      "stock" -> :stock
      "accounts" -> :accounts
      "contacts" -> :contacts
      _ -> :stock
    end

    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("save-opening-stock", %{"opening_stock" => params}, socket) do
    tenant_id = socket.assigns.tenant_id

    with {:ok, product_id} <- parse_integer(params["product_id"]),
         {:ok, warehouse_id} <- parse_integer(params["warehouse_id"]),
         quantity <- Decimal.new(params["quantity"] || "0"),
         cost <- Decimal.new(params["cost"] || "0") do

      case Inventory.set_opening_balance(tenant_id, product_id, warehouse_id, quantity, cost) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Началното салдо е записано успешно!")
           |> load_data()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Невалидни данни")}
    end
  end

  @impl true
  def handle_event("save-opening-account", %{"opening_account" => params}, socket) do
    tenant_id = socket.assigns.tenant_id

    with {:ok, account_id} <- parse_integer(params["account_id"]),
         balance <- Decimal.new(params["balance"] || "0") do

      case Accounting.set_account_opening_balance(tenant_id, account_id, balance) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Началното салдо на сметката е записано успешно!")
           |> load_data()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Невалидни данни")}
    end
  end

  @impl true
  def handle_event("save-opening-contact", %{"opening_contact" => params}, socket) do
    tenant_id = socket.assigns.tenant_id

    with {:ok, contact_id} <- parse_integer(params["contact_id"]),
         debit <- Decimal.new(params["debit_balance"] || "0"),
         credit <- Decimal.new(params["credit_balance"] || "0") do

      contact = Contacts.get_contact!(tenant_id, contact_id)

      case Contacts.update_contact(contact, %{
        opening_debit_balance: debit,
        opening_credit_balance: credit
      }) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Началното салдо на контрагента е записано успешно!")
           |> load_data()}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Грешка при записване")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Невалидни данни")}
    end
  end

  @impl true
  def handle_event("remove-product-balance", %{"id" => id}, socket) do
    tenant_id = socket.assigns.tenant_id
    product_id = String.to_integer(id)

    case Inventory.remove_opening_balance(tenant_id, product_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Началното салдо е премахнато!")
         |> load_data()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("remove-account-balance", %{"id" => id}, socket) do
    tenant_id = socket.assigns.tenant_id
    account_id = String.to_integer(id)

    case Accounting.remove_account_opening_balance(tenant_id, account_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Началното салдо е премахнато!")
         |> load_data()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("remove-contact-balance", %{"id" => id}, socket) do
    tenant_id = socket.assigns.tenant_id
    contact_id = String.to_integer(id)

    contact = Contacts.get_contact!(tenant_id, contact_id)

    case Contacts.update_contact(contact, %{
      opening_debit_balance: Decimal.new(0),
      opening_credit_balance: Decimal.new(0)
    }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Началното салдо е премахнато!")
         |> load_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при премахване")}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  defp parse_integer(nil), do: {:error, :invalid}
  defp parse_integer(""), do: {:error, :invalid}
  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> {:ok, int}
      :error -> {:error, :invalid}
    end
  end
  defp parse_integer(val) when is_integer(val), do: {:ok, val}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h1 class="text-2xl font-bold text-gray-800 mb-2">Начални салда</h1>
        <p class="text-gray-600 mb-6">Въведете началните салда за складови наличности, счетоводни сметки и контрагенти</p>

        <!-- Tabs -->
        <div class="border-b border-gray-200 mb-6">
          <nav class="-mb-px flex space-x-8">
            <button
              phx-click="change-tab"
              phx-value-tab="stock"
              class={"#{if @active_tab == :stock, do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}>
              Складови наличности
            </button>
            <button
              phx-click="change-tab"
              phx-value-tab="accounts"
              class={"#{if @active_tab == :accounts, do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}>
              Счетоводни сметки
            </button>
            <button
              phx-click="change-tab"
              phx-value-tab="contacts"
              class={"#{if @active_tab == :contacts, do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}>
              Контрагенти
            </button>
          </nav>
        </div>

        <!-- Stock Form -->
        <%= if @active_tab == :stock do %>
          <.form for={%{}} as={:opening_stock} phx-submit="save-opening-stock" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Продукт</label>
                <select name="opening_stock[product_id]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете продукт</option>
                  <%= for product <- @products do %>
                    <option value={product.id}><%= product.name %> (<%= product.sku %>)</option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Склад</label>
                <select name="opening_stock[warehouse_id]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете склад</option>
                  <%= for warehouse <- @warehouses do %>
                    <option value={warehouse.id}><%= warehouse.name %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Количество</label>
                <input type="number" step="0.001" name="opening_stock[quantity]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Единична цена</label>
                <input type="number" step="0.01" name="opening_stock[cost]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="flex justify-end">
              <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Запис
              </button>
            </div>
          </.form>
        <% end %>

        <!-- Accounts Form -->
        <%= if @active_tab == :accounts do %>
          <.form for={%{}} as={:opening_account} phx-submit="save-opening-account" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Счетоводна сметка</label>
                <select name="opening_account[account_id]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете сметка</option>
                  <%= for account <- @accounts do %>
                    <option value={account.id}><%= account.code %> - <%= account.name %></option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Начално салдо</label>
                <input type="number" step="0.01" name="opening_account[balance]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="flex justify-end">
              <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Запис
              </button>
            </div>
          </.form>
        <% end %>

        <!-- Contacts Form -->
        <%= if @active_tab == :contacts do %>
          <.form for={%{}} as={:opening_contact} phx-submit="save-opening-contact" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Контрагент</label>
                <select name="opening_contact[contact_id]" required class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете контрагент</option>
                  <%= for contact <- @contacts do %>
                    <option value={contact.id}>
                      <%= contact.name %>
                      <%= if contact.registration_number do %>(<%= contact.registration_number %>)<% end %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Дебитно салдо (вземане)</label>
                <input type="number" step="0.01" name="opening_contact[debit_balance]" value="0" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
                <p class="mt-1 text-xs text-gray-500">Контрагентът ни дължи</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Кредитно салдо (задължение)</label>
                <input type="number" step="0.01" name="opening_contact[credit_balance]" value="0" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
                <p class="mt-1 text-xs text-gray-500">Ние дължим на контрагента</p>
              </div>
            </div>

            <div class="flex justify-end">
              <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Запис
              </button>
            </div>
          </.form>
        <% end %>
      </div>

      <!-- Existing Balances Table -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Съществуващи начални салда</h2>

        <%= if @active_tab == :stock do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Продукт</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Количество</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Стойност</th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Действия</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for product <- @products_with_balances do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900"><%= product.name %></div>
                      <div class="text-sm text-gray-500"><%= product.sku %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if product.opening_quantity, do: Decimal.to_string(product.opening_quantity), else: "-" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if product.opening_quantity && product.opening_cost do %>
                        <%= Decimal.to_string(Decimal.mult(product.opening_quantity, product.opening_cost)) %> лв.
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button phx-click="remove-product-balance" phx-value-id={product.id} class="text-red-600 hover:text-red-900">
                        Премахни
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @products_with_balances == [] do %>
              <p class="text-center py-8 text-gray-500">Няма въведени начални салда за продукти</p>
            <% end %>
          </div>
        <% end %>

        <%= if @active_tab == :accounts do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Сметка</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Салдо</th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Действия</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for account <- @accounts_with_balances do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900"><%= account.name %></div>
                      <div class="text-sm text-gray-500"><%= account.code %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if account.opening_balance, do: Decimal.to_string(account.opening_balance), else: "-" %> лв.
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button phx-click="remove-account-balance" phx-value-id={account.id} class="text-red-600 hover:text-red-900">
                        Премахни
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @accounts_with_balances == [] do %>
              <p class="text-center py-8 text-gray-500">Няма въведени начални салда за сметки</p>
            <% end %>
          </div>
        <% end %>

        <%= if @active_tab == :contacts do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Контрагент</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Дебит (вземане)</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Кредит (задължение)</th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Действия</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for contact <- @contacts_with_balances do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900"><%= contact.name %></div>
                      <div class="text-sm text-gray-500"><%= contact.registration_number %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-green-600 font-medium">
                      <%= if contact.opening_debit_balance && Decimal.compare(contact.opening_debit_balance, 0) != :eq do %>
                        <%= Decimal.to_string(contact.opening_debit_balance) %> лв.
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-red-600 font-medium">
                      <%= if contact.opening_credit_balance && Decimal.compare(contact.opening_credit_balance, 0) != :eq do %>
                        <%= Decimal.to_string(contact.opening_credit_balance) %> лв.
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button phx-click="remove-contact-balance" phx-value-id={contact.id} class="text-red-600 hover:text-red-900">
                        Премахни
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @contacts_with_balances == [] do %>
              <p class="text-center py-8 text-gray-500">Няма въведени начални салда за контрагенти</p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
