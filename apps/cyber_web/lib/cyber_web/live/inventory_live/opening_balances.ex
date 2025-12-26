defmodule CyberWeb.InventoryLive.OpeningBalances do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Accounting

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"]
    
    products = Inventory.list_products(tenant_id)
    products_with_balances = Inventory.list_products_with_opening_balances(tenant_id)
    warehouses = Inventory.list_warehouses(tenant_id)
    accounts = Accounting.list_accounts(tenant_id)
    accounts_with_balances = Accounting.list_accountsWithOpeningBalances(tenant_id)
    
    {:ok,
     socket
     |> assign(:tenant_id, tenant_id)
     |> assign(:products, products)
     |> assign(:products_with_balances, products_with_balances)
     |> assign(:warehouses, warehouses)
     |> assign(:accounts, accounts)
     |> assign(:accounts_with_balances, accounts_with_balances)
     |> assign(:changeset, nil)
     |> assign(:form_step, :stock)}
  end

  @impl true
  def handle_event("validate", %{"product" => _product_params}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save-opening-stock", %{"opening_stock" => opening_stock_params}, socket) do
    tenant_id = socket.assigns.tenant_id
    
    case process_opening_stock_balance(tenant_id, opening_stock_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Началното салдо е записано успешно!")
         |> push_navigate(to: "/inventory/opening-balances")}
         
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при записване на началното салдо: #{reason}")
         |> push_navigate(to: "/inventory/opening-balances")}
    end
  end

  @impl true
  def handle_event("save-opening-account", %{"opening_account" => opening_account_params}, socket) do
    tenant_id = socket.assigns.tenant_id
    
    case process_opening_account_balance(tenant_id, opening_account_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Началното салдо на сметката е записано успешно!")
         |> push_navigate(to: "/accounting/opening-balances")}
         
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при записване на началното салдо на сметката: #{reason}")
         |> push_navigate(to: "/accounting/opening-balances")}
    end
  end

  @impl true
  def handle_event("remove-product-opening-balance", %{"id" => product_id}, socket) do
    tenant_id = socket.assigns.tenant_id
    product_id = String.to_integer(product_id)
    
    case Inventory.remove_opening_balance(tenant_id, product_id) do
      {:ok, _} ->
        # Обновяване на списъка с продукти
        products_with_balances = Inventory.list_products_with_opening_balances(tenant_id)
        
        {:noreply,
         socket
         |> assign(:products_with_balances, products_with_balances)
         |> put_flash(:info, "Началното салдо е премахнато успешно!")}
         
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при премахване на началното салдо: #{reason}")} 
    end
  end

  @impl true
  def handle_event("remove-account-opening-balance", %{"id" => account_id}, socket) do
    tenant_id = socket.assigns.tenant_id
    account_id = String.to_integer(account_id)
    
    case Accounting.remove_account_opening_balance(tenant_id, account_id) do
      {:ok, _} ->
        # Обновяване на списъка със сметки
        accounts_with_balances = Accounting.list_accountsWithOpeningBalances(tenant_id)
        
        {:noreply,
         socket
         |> assign(:accounts_with_balances, accounts_with_balances)
         |> put_flash(:info, "Началното салдо на сметката е премахнато успешно!")}
         
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при премахване на началното салдо на сметката: #{reason}")} 
    end
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    step = case tab do
      "stock" -> :stock
      "accounts" -> :accounts
      _ -> :stock
    end
    
    {:noreply, assign(socket, :form_step, step)}
  end

  defp process_opening_stock_balance(tenant_id, params) do
    product_id = String.to_integer(params["product_id"])
    warehouse_id = String.to_integer(params["warehouse_id"])
    quantity = Decimal.new(params["quantity"] || "0")
    cost = Decimal.new(params["cost"] || "0")
    
    try do
      Inventory.set_opening_balance(tenant_id, product_id, warehouse_id, quantity, cost)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp process_opening_account_balance(tenant_id, params) do
    account_id = String.to_integer(params["account_id"])
    balance = Decimal.new(params["balance"] || "0")
    
    try do
      Accounting.set_account_opening_balance(tenant_id, account_id, balance)
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="bg-white rounded-lg shadow-md p-6 mb-8">
        <h1 class="text-2xl font-bold text-gray-800 mb-2">Начални салда</h1>
        <p class="text-gray-600 mb-6">Въведете началните салда за складови наличности и счетоводни сметки</p>
        
        <div class="border-b border-gray-200 mb-6">
          <nav class="-mb-px flex space-x-8">
            <button
              phx-click="change-tab"
              phx-value-tab="stock"
              class={"#{if @form_step == :stock, do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}>
              Складови наличности
            </button>
            <button
              phx-click="change-tab"
              phx-value-tab="accounts"
              class={"#{if @form_step == :accounts, do: "border-indigo-500 text-indigo-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"} whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}>
              Счетоводни сметки
            </button>
          </nav>
        </div>
        
        <%= if @form_step == :stock do %>
          <.form for={%{}} as={:opening_stock} phx-submit="save-opening-stock" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Продукт</label>
                <select name="opening_stock[product_id]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете продукт</option>
                  <%= for product <- @products do %>
                    <option value={product.id}><%= product.name %> (<%= product.sku %>)</option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Склад</label>
                <select name="opening_stock[warehouse_id]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете склад</option>
                  <%= for warehouse <- @warehouses do %>
                    <option value={warehouse.id}><%= warehouse.name %></option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Количество</label>
                <input type="number" step="0.01" name="opening_stock[quantity]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Единична цена</label>
                <input type="number" step="0.01" name="opening_stock[cost]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>
            
            <div class="flex justify-end">
              <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Запис на началното салдо
              </button>
            </div>
          </.form>
        <% end %>
        
        <%= if @form_step == :accounts do %>
          <.form for={%{}} as={:opening_account} phx-submit="save-opening-account" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Счетоводна сметка</label>
                <select name="opening_account[account_id]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
                  <option value="">Изберете сметка</option>
                  <%= for account <- @accounts do %>
                    <option value={account.id}><%= account.code %> - <%= account.name %></option>
                  <% end %>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Начално салдо</label>
                <input type="number" step="0.01" name="opening_account[balance]" class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>
            
            <div class="flex justify-end">
              <button type="submit" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Запис на началното салдо
              </button>
            </div>
          </.form>
        <% end %>
      </div>
      
      <div class="bg-white rounded-lg shadow-md p-6">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Съществуващи начални салда</h2>
        
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Продукт/Сметка</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Количество/Салдо</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Стойност</th>
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
                    <%= Decimal.to_string(product.opening_quantity) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= if product.opening_cost do %>
                      <%= Decimal.to_string(Decimal.mult(product.opening_quantity, product.opening_cost)) %>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button phx-click="remove-product-opening-balance" phx-value-id={product.id} class="text-red-600 hover:text-red-900">
                      Премахване
                    </button>
                  </td>
                </tr>
              <% end %>
              
              <%= for account <- @accounts_with_balances do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900"><%= account.name %></div>
                    <div class="text-sm text-gray-500"><%= account.code %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Decimal.to_string(account.opening_balance) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <!-- Няма допълнителна стойност за сметки -->
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button phx-click="remove-account-opening-balance" phx-value-id={account.id} class="text-red-600 hover:text-red-900">
                      Премахване
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end