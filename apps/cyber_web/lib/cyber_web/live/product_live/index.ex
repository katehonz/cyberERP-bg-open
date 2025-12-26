defmodule CyberWeb.ProductLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Inventory
  alias CyberCore.Inventory.Product

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Артикули")
     |> assign(:products, [])
     |> assign(:category_filter, "all")
     |> assign(:search_query, "")
     |> load_products()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    category = params["category"] || "all"

    {:noreply,
     socket
     |> assign(:category_filter, category)
     |> load_products()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, page_title(socket.assigns.category_filter))
    |> assign(:product, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов артикул")
    |> assign(:product, %Product{category: socket.assigns.category_filter})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    product = Inventory.get_product!(@tenant_id, id)

    socket
    |> assign(:page_title, "Редактиране на артикул")
    |> assign(:product, product)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Inventory.get_product!(@tenant_id, id)
    {:ok, _} = Inventory.delete_product(product)

    {:noreply,
     socket
     |> put_flash(:info, "Артикулът беше изтрит успешно")
     |> load_products()}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, push_patch(socket, to: ~p"/products?category=#{category}")}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_products()}
  end

  defp load_products(socket) do
    opts = build_filter_opts(socket)

    products =
      Inventory.list_products(@tenant_id, opts)
      |> CyberCore.Repo.preload(:cn_code)

    assign(socket, :products, products)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:category, category_value(socket.assigns.category_filter))
    |> maybe_put(:search, socket.assigns.search_query)
  end

  defp category_value("all"), do: nil
  defp category_value(category), do: category

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp page_title("goods"), do: "Стоки"
  defp page_title("materials"), do: "Материали"
  defp page_title("produced"), do: "Произведена продукция"
  defp page_title("services"), do: "Услуги"
  defp page_title(_), do: "Всички артикули"

  defp category_name("goods"), do: "Стока"
  defp category_name("materials"), do: "Материал"
  defp category_name("produced"), do: "Произведена"
  defp category_name("services"), do: "Услуга"
  defp category_name(_), do: "Неопределен"

  defp category_badge("goods"),
    do: "inline-flex rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-600"

  defp category_badge("materials"),
    do: "inline-flex rounded-full bg-amber-100 px-2 py-1 text-xs font-medium text-amber-600"

  defp category_badge("produced"),
    do: "inline-flex rounded-full bg-violet-100 px-2 py-1 text-xs font-medium text-violet-600"

  defp category_badge("services"),
    do: "inline-flex rounded-full bg-blue-100 px-2 py-1 text-xs font-medium text-blue-600"

  defp category_badge(_),
    do: "inline-flex rounded-full bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-600"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-1 text-sm text-gray-600">
            Управление на стоки, материали и услуги
          </p>
        </div>
        <.link
          patch={~p"/products/new?category=#{@category_filter}"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нов артикул
        </.link>
      </div>

      <!-- Филтри -->
      <div class="flex flex-col gap-4 rounded-lg border border-gray-200 bg-white p-4 shadow-sm sm:flex-row">
        <!-- Категории -->
        <div class="flex flex-wrap gap-2">
          <button
            phx-click="filter_category"
            phx-value-category="all"
            class={"rounded-md px-4 py-2 text-sm font-medium transition " <> if @category_filter == "all",
              do: "bg-indigo-600 text-white",
              else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}
          >
            Всички
          </button>
          <button
            phx-click="filter_category"
            phx-value-category="goods"
            class={"rounded-md px-4 py-2 text-sm font-medium transition " <> if @category_filter == "goods",
              do: "bg-emerald-600 text-white",
              else: "bg-emerald-100 text-emerald-700 hover:bg-emerald-200"}
          >
            📦 Стоки
          </button>
          <button
            phx-click="filter_category"
            phx-value-category="materials"
            class={"rounded-md px-4 py-2 text-sm font-medium transition " <> if @category_filter == "materials",
              do: "bg-amber-600 text-white",
              else: "bg-amber-100 text-amber-700 hover:bg-amber-200"}
          >
            🔧 Материали
          </button>
          <button
            phx-click="filter_category"
            phx-value-category="produced"
            class={"rounded-md px-4 py-2 text-sm font-medium transition " <> if @category_filter == "produced",
              do: "bg-violet-600 text-white",
              else: "bg-violet-100 text-violet-700 hover:bg-violet-200"}
          >
            🏭 Произведена
          </button>
          <button
            phx-click="filter_category"
            phx-value-category="services"
            class={"rounded-md px-4 py-2 text-sm font-medium transition " <> if @category_filter == "services",
              do: "bg-blue-600 text-white",
              else: "bg-blue-100 text-blue-700 hover:bg-blue-200"}
          >
            ⚙️ Услуги
          </button>
        </div>

        <!-- Търсене -->
        <div class="flex-1">
          <form phx-change="search" class="relative">
            <input
              type="text"
              name="search"
              value={@search_query}
              placeholder="Търсене по име, SKU или описание..."
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </form>
        </div>
      </div>

      <!-- Таблица -->
      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                SKU
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Име
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Категория
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Цена
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Единица
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                КН Код
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Действия
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for product <- @products do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <%= product.sku %>
                </td>
                <td class="px-4 py-3">
                  <div class="text-sm font-medium text-gray-900"><%= product.name %></div>
                  <div class="text-sm text-gray-500"><%= product.description %></div>
                </td>
                <td class="px-4 py-3 text-sm">
                  <span class={category_badge(product.category)}>
                    <%= category_name(product.category) %>
                  </span>
                </td>
                <td class="px-4 py-3 text-right text-sm text-gray-900">
                  <%= if product.price do %>
                    <%= Decimal.to_string(product.price) %> лв.
                  <% else %>
                    -
                  <% end %>
                </td>
                <td class="px-4 py-3 text-sm text-gray-500">
                  <%= product.unit || "бр." %>
                </td>
                <td class="px-4 py-3 text-sm text-gray-500">
                  <%= if product.cn_code do %>
                    <span class="font-mono text-xs bg-gray-100 px-2 py-1 rounded" title={product.cn_code.description}>
                      <%= product.cn_code.code %>
                    </span>
                  <% else %>
                    <span class="text-gray-400">-</span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-right text-sm">
                  <.link
                    patch={~p"/products/#{product}/edit"}
                    class="text-indigo-600 hover:text-indigo-700 mr-3"
                  >
                    Редакция
                  </.link>
                  <a
                    href="#"
                    phx-click="delete"
                    phx-value-id={product.id}
                    data-confirm="Сигурни ли сте?"
                    class="text-red-600 hover:text-red-700"
                  >
                    Изтриване
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if @products == [] do %>
          <div class="text-center py-12">
            <div class="mx-auto h-12 w-12 text-gray-400 text-4xl">📦</div>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Няма артикули</h3>
            <p class="mt-1 text-sm text-gray-500">
              Започнете като създадете нов артикул.
            </p>
            <div class="mt-6">
              <.link
                patch={~p"/products/new?category=#{@category_filter}"}
                class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
              >
                + Нов артикул
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="product-modal"
      show
      on_cancel={~p"/products?category=#{@category_filter}"}
    >
      <.live_component
        module={CyberWeb.ProductLive.FormComponent}
        id={@product.id || :new}
        title={@page_title}
        action={@live_action}
        product={@product}
        patch={~p"/products?category=#{@category_filter}"}
      />
    </.modal>
    """
  end
end
