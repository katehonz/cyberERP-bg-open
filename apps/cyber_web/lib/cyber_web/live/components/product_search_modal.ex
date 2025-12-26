defmodule CyberWeb.Components.ProductSearchModal do
  use CyberWeb, :live_component

  alias Phoenix.LiveView.JS
  alias CyberCore.Inventory
  alias Decimal, as: D

  @impl true
  def mount(socket) do
    products = Inventory.list_products(1)
    categories = get_product_categories(products)

    {:ok,
      socket
      |> assign(:products, products)
      |> assign(:filtered_products, products)
      |> assign(:categories, categories)
      |> assign(:product_search, "")
      |> assign(:selected_category, "all")
    }
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("search_products", %{"search" => search}, socket) do
    search = String.trim(search)
    filtered = filter_products(socket.assigns.products, search, socket.assigns.selected_category)

    {:noreply,
      socket
      |> assign(:product_search, search)
      |> assign(:filtered_products, filtered)}
  end

  def handle_event("select_category", %{"category" => category}, socket) do
    filtered = filter_products(socket.assigns.products, socket.assigns.product_search, category)

    {:noreply,
      socket
      |> assign(:selected_category, category)
      |> assign(:filtered_products, filtered)}
  end

  def handle_event("select_product", %{"product-id" => product_id}, socket) do
    product_id = String.to_integer(product_id)
    product = Enum.find(socket.assigns.products, &(&1.id == product_id))

    send(socket.assigns.caller, {:search_modal_selected, %{item: product, field: socket.assigns.field}})
    {:noreply, socket}
  end

  def handle_event("hide_search_modal", _, socket) do
    send(socket.assigns.caller, {:search_modal_cancelled, %{}})
    {:noreply, socket}
  end


  defp filter_products(products, search, category) do
    products
    |> filter_by_category(category)
    |> filter_by_search(search)
  end

  defp filter_by_category(products, "all"), do: products

  defp filter_by_category(products, category) do
    Enum.filter(products, fn product ->
      product.category == category
    end)
  end

  defp filter_by_search(products, ""), do: products

  defp filter_by_search(products, term) do
    down = String.downcase(term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name || ""), down) or
        String.contains?(String.downcase(product.sku || ""), down)
    end)
  end

  defp get_product_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp category_label("goods"), do: "Стоки"
  defp category_label("materials"), do: "Материали"
  defp category_label("services"), do: "Услуги"
  defp category_label("produced"), do: "Произведена продукция"
  defp category_label(category), do: category

  defp category_icon("goods") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
    </svg>
    """
  end

  defp category_icon("materials") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
    </svg>
    """
  end

  defp category_icon("services") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    """
  end

  defp category_icon("produced") do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
    </svg>
    """
  end

  defp category_icon(_) do
    """
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
    </svg>
    """
  end

  defp format_money(nil), do: "0.00"
  defp format_money(amount) do
      amount
      |> D.round(2)
      |> D.to_string(:normal)
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@show} class="fixed inset-0 z-50 flex items-start justify-center bg-black bg-opacity-60 p-4 pt-[10vh]">
        <div class="w-full max-w-4xl rounded-2xl bg-white shadow-2xl flex flex-col max-h-[80vh]" phx-click-away={JS.push("hide_search_modal", target: @myself)}>
            <!-- Хедър на модала -->
            <div class="p-6 border-b-2 border-gray-100">
                <div class="flex justify-between items-center">
                    <h2 class="text-2xl font-bold text-gray-900"><%= @title %></h2>
                    <button type="button" phx-click={JS.push("hide_search_modal", target: @myself)} class="p-2 rounded-full text-gray-400 hover:bg-gray-200 hover:text-gray-600">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                    </button>
                </div>
                 <!-- Търсене -->
                <div class="mt-4">
                  <form phx-change="search_products" phx-target={@myself} class="flex items-center gap-3">
                    <div class="relative flex-1">
                      <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                        <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                        </svg>
                      </div>
                      <input
                        type="text"
                        name="search"
                        value={@product_search}
                        placeholder="Търсене по име или SKU..."
                        class="w-full rounded-lg border-gray-300 pl-10 text-base focus:border-indigo-500 focus:ring-indigo-500"
                      />
                    </div>
                  </form>

                  <!-- Категории -->
                  <div class="mt-4 flex gap-2 overflow-x-auto pb-2">
                    <button
                      type="button"
                      phx-click="select_category"
                      phx-target={@myself}
                      phx-value-category="all"
                      class={"inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition " <> if @selected_category == "all", do: "bg-indigo-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}
                    >
                      <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path></svg>
                      <span>Всички</span>
                    </button>
                    <%= for category <- @categories do %>
                      <button
                        type="button"
                        phx-click="select_category"
                        phx-target={@myself}
                        phx-value-category={category}
                        class={"inline-flex items-center gap-2 whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition " <> if @selected_category == category, do: "bg-indigo-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}
                      >
                        <span :if={category_icon(category)} class="inline-block"><%= Phoenix.HTML.raw(category_icon(category)) %></span>
                        <span><%= category_label(category) %></span>
                      </button>
                    <% end %>
                  </div>
                </div>
            </div>
            <!-- Продуктова мрежа в модал -->
            <div class="flex-1 overflow-y-auto p-6">
              <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                <%= for product <- @filtered_products do %>
                  <button
                    type="button"
                    phx-click="select_product"
                    phx-target={@myself}
                    phx-value-product-id={product.id}
                    class="group relative flex h-36 flex-col justify-between rounded-xl border-2 border-gray-200 bg-gradient-to-br from-white to-gray-50 p-4 text-left shadow-sm transition hover:border-indigo-500 hover:shadow-lg hover:-translate-y-1"
                  >
                    <div class="absolute right-3 top-3 opacity-0 transition-opacity group-hover:opacity-100">
                      <svg class="h-8 w-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                    </div>
                    <div>
                      <p class="text-base font-bold text-gray-900 line-clamp-2"><%= product.name %></p>
                      <p class="mt-1 text-sm text-gray-500">SKU: <%= product.sku %></p>
                    </div>
                    <div class="flex items-end justify-between">
                      <p class="text-xl font-bold text-indigo-600"><%= format_money(product.price) %> лв.</p>
                      <span :if={product.category} class="text-xs font-medium text-gray-400"><%= category_label(product.category) %></span>
                    </div>
                  </button>
                <% end %>
              </div>
              <%= if @filtered_products == [] do %>
                <div class="flex h-64 items-center justify-center">
                  <div class="text-center">
                    <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path></svg>
                    <p class="mt-4 text-lg font-medium text-gray-900">Няма намерени продукти</p>
                    <p class="mt-1 text-sm text-gray-500">Опитайте с различна категория или търсене</p>
                  </div>
                </div>
              <% end %>
            </div>
             <div class="p-4 bg-gray-50 border-t-2 border-gray-100 text-right">
                  <button type="button" phx-click={JS.push("hide_search_modal", target: @myself)} class="px-6 py-3 rounded-lg bg-gray-200 text-gray-800 font-semibold hover:bg-gray-300">Затвори</button>
             </div>
          </div>
        </div>
      </div>
    """
  end
end
