defmodule CyberWeb.ProductionOrderLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Manufacturing
  alias CyberCore.Inventory

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    recipes = Manufacturing.list_recipes(@tenant_id)
    products = Inventory.list_products(@tenant_id)
    warehouses = Inventory.list_warehouses(@tenant_id)
    {:ok, accounting_settings} = CyberCore.Settings.get_or_create_accounting_settings(@tenant_id)
    
    socket = 
      socket
      |> assign(:page_title, "Производствени поръчки")
      |> assign(:orders, [])
      |> assign(:order, nil)
      |> assign(:form, nil)
      |> assign(:recipes, recipes)
      |> assign(:products, products)
      |> assign(:warehouses, warehouses)
      |> assign(:accounting_settings, accounting_settings)
      |> load_orders()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:order, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    order = %Manufacturing.ProductionOrder{
      order_number: "PO-" <> Integer.to_string(System.unique_integer([:positive])),
      planned_date: Date.utc_today(),
      quantity_to_produce: 1,
      warehouse_id: hd(socket.assigns.warehouses).id
    }
    changeset = Manufacturing.change_production_order(order)

    socket
    |> assign(:order, order)
    |> assign(:form, to_form(changeset))
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    order = Manufacturing.get_production_order!(@tenant_id, id)
    changeset = Manufacturing.change_production_order(order)
    
    socket
    |> assign(:order, order)
    |> assign(:form, to_form(changeset))
  end

  defp load_orders(socket) do
    orders = Manufacturing.list_production_orders(@tenant_id)
    assign(socket, :orders, orders)
  end

  @impl true
  def handle_event("save", %{"production_order" => order_params}, socket) do
    save_order(socket, socket.assigns.live_action, order_params)
  end

  @impl true
  def handle_event("start_order", %{"id" => id}, socket) do
    order = Manufacturing.get_production_order!(@tenant_id, id)
    case Manufacturing.start_production_order(order) do
      {:ok, _} -> {:noreply, load_orders(socket) |> put_flash(:info, "Поръчката е стартирана.")}
      {:error, errors} when is_list(errors) -> {:noreply, put_flash(socket, :error, "Грешка: " <> Enum.join(errors, ", "))}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Грешка при стартиране на поръчката.")}
    end
  end

  @impl true
  def handle_event("complete_order", %{"id" => id}, socket) do
    order = Manufacturing.get_production_order!(@tenant_id, id)
    # Use the planned quantity as produced quantity
    quantity_produced = order.quantity
    case Manufacturing.complete_production_order(order, quantity_produced, socket.assigns.current_user_id, socket.assigns.accounting_settings) do
      {:ok, _} -> {:noreply, load_orders(socket) |> put_flash(:info, "Поръчката е завършена.")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Грешка при завършване на поръчката.")}
    end
  end

  @impl true
  def handle_event("cancel_order", %{"id" => id}, socket) do
    order = Manufacturing.get_production_order!(@tenant_id, id)
    case Manufacturing.update_production_order(order, %{status: "canceled"}) do
      {:ok, _} -> {:noreply, load_orders(socket) |> put_flash(:info, "Поръчката е отказана.")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Грешка при отказване на поръчката.")}
    end
  end

  defp save_order(socket, :new, order_params) do
    case Manufacturing.create_production_order(Map.put(order_params, "tenant_id", @tenant_id)) do
      {:ok, _order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Производствена поръчка създадена.")
         |> push_patch(to: ~p"/production-orders")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_order(socket, :edit, order_params) do
    order = socket.assigns.order
    case Manufacturing.update_production_order(order, order_params) do
      {:ok, _order} ->
        {:noreply,
          socket
          |> put_flash(:info, "Промените са запазени.")
          |> push_patch(to: ~p"/production-orders")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-semibold text-gray-900">Производствени поръчки</h1>

      <%= if @live_action in [:new, :edit] do %>
        <.simple_form for={@form} phx-submit="save">
          <.input field={@form[:order_number]} label="Номер на поръчка" />
          <.input field={@form[:description]} label="Описание" />
          <.input field={@form[:warehouse_id]} type="select" label="Склад" options={for w <- @warehouses, do: {w.name, w.id}} />
          <.input field={@form[:recipe_id]} type="select" label="Рецепта" options={for r <- @recipes, do: {r.name, r.id}} />
          <.input field={@form[:output_product_id]} type="select" label="Продукт" options={for p <- @products, do: {p.name, p.id}} />
          <.input field={@form[:quantity_to_produce]} label="Количество за производство" type="number" step="0.01" />
          <.input field={@form[:planned_date]} type="date" label="Планирана дата" />
          <:actions>
            <.button>Запази</.button>
            <.link patch={~p"/production-orders"}>Отказ</.link>
          </:actions>
        </.simple_form>
      <% else %>
        <.link patch={~p"/production-orders/new"}>
          <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Нова поръчка</button>
        </.link>
        <table class="min-w-full divide-y divide-gray-300 mt-4">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Номер</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Продукт</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Количество</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Статус</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Планирана</th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                <span class="sr-only">Действия</span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= for order <- @orders do %>
              <tr>
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= order.order_number %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.output_product && order.output_product.name %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.quantity_to_produce %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.status %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= order.planned_date %></td>
                <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                  <%= if order.status == "planned" do %>
                    <button phx-click="start_order" phx-value-id={order.id} class="text-green-600 hover:text-green-900">Старт</button>
                  <% end %>
                  <%= if order.status == "in_progress" do %>
                    <button phx-click="complete_order" phx-value-id={order.id} class="text-blue-600 hover:text-blue-900">Завърши</button>
                  <% end %>
                  <%= if order.status in ["planned", "in_progress"] do %>
                    <button phx-click="cancel_order" phx-value-id={order.id} class="text-red-600 hover:text-red-900 ml-4">Откажи</button>
                  <% end %>
                  <.link patch={~p"/production-orders/#{order.id}/edit"} class="text-indigo-600 hover:text-indigo-900 ml-4">Редактирай</.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end
end
