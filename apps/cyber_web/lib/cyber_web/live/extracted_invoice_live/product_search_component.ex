defmodule CyberWeb.ExtractedInvoiceLive.ProductSearchComponent do
  use CyberWeb, :live_component

  alias CyberCore.Inventory

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       query: "",
       search_results: [],
       show_results: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <input
        type="text"
        phx-target={@myself}
        phx-keydown="search"
        value={@query}
        placeholder="Търси продукт..."
        class="w-full rounded-md border-gray-300 text-sm"
      />
      <%= if @show_results do %>
        <div class="absolute z-10 w-full bg-white border border-gray-300 rounded-md mt-1 shadow-lg">
          <ul>
            <%= for product <- @search_results do %>
              <li
                phx-click="select_product"
                phx-target={@myself}
                phx-value-id={product.id}
                class="px-4 py-2 cursor-pointer hover:bg-gray-100"
              >
                <%= product.name %>
              </li>
            <% end %>
            <%= if @search_results == [] do %>
              <li class="px-4 py-2 text-gray-500">Няма намерени резултати</li>
              <li
                phx-click="create_product"
                phx-target={@myself}
                phx-value-query={@query}
                class="px-4 py-2 cursor-pointer hover:bg-gray-100 font-medium text-teal-600"
              >
                + Създай нов продукт "<%= @query %>"
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"key" => "ArrowDown"}, socket) do
    # TODO: Implement keyboard navigation
    {:noreply, socket}
  end

  def handle_event("search", %{"key" => "ArrowUp"}, socket) do
    # TODO: Implement keyboard navigation
    {:noreply, socket}
  end

  def handle_event("search", %{"key" => "Enter"}, socket) do
    # TODO: Implement keyboard navigation
    {:noreply, socket}
  end

  def handle_event("search", %{"value" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Inventory.search_products(socket.assigns.current_tenant_id, query, limit: 10)
      else
        []
      end

    socket =
      socket
      |> assign(:query, query)
      |> assign(:search_results, results)
      |> assign(:show_results, true)

    {:noreply, socket}
  end

  def handle_event("select_product", %{"id" => product_id}, socket) do
    send(
      socket.assigns.target,
      {:select_product, %{"index" => socket.assigns.line_item_index, "product_id" => product_id}}
    )

    {:noreply, assign(socket, :show_results, false)}
  end

  def handle_event("create_product", %{"query" => product_name}, socket) do
    send(
      socket.assigns.target,
      {:open_create_product_modal,
       %{name: product_name, line_item_index: socket.assigns.line_item_index}}
    )

    {:noreply, assign(socket, :show_results, false)}
  end
end
