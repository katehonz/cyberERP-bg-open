defmodule CyberWeb.StockDocumentLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Inventory.StockMovement

  def mount(_params, _session, socket) do
    products = Inventory.list_products(1)
    warehouses = Inventory.list_warehouses(1)

    {:ok,
     socket
     |> assign(:page_title, "Складови документи")
     |> assign(:products, products)
     |> assign(:warehouses, warehouses)
     |> assign(:form, to_form(StockMovement.changeset(%StockMovement{}, %{})))}
  end

  def handle_event("save", %{"stock_movement" => params}, socket) do
    params = Map.put(params, "tenant_id", 1)
    case Inventory.create_stock_movement(params) do
      {:ok, _movement} ->
        {:noreply,
         socket
         |> put_flash(:info, "Складовият документ е създаден успешно.")
         |> redirect(to: ~p"/stock-movements")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
      <p class="mt-2 text-sm text-gray-700">
        Създаване на документи за брак, липса и излишък.
      </p>

      <div class="mt-8">
        <.simple_form for={@form} phx-submit="save">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <.input field={@form[:movement_type]} type="select" label="Вид документ" options={[
              {"Брак", "scrapping"},
              {"Липса", "shortage"},
              {"Излишък", "surplus"}
            ]} />
            <.input field={@form[:movement_date]} type="date" label="Дата" />
            <.input field={@form[:product_id]} type="select" label="Продукт" options={Enum.map(@products, &{&1.name, &1.id})} />
            <.input field={@form[:warehouse_id]} type="select" label="Склад" options={Enum.map(@warehouses, &{&1.name, &1.id})} />
            <.input field={@form[:quantity]} type="number" label="Количество" step="0.01" />
            <.input field={@form[:notes]} type="textarea" label="Бележки" />
          </div>
          <:actions>
            <.button>Запази</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
