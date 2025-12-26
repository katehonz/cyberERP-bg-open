defmodule CyberWeb.NomenclatureLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.SAFT.Nomenclature.{
    InvoiceType,
    PaymentMethod,
    StockMovementType,
    InventoryType,
    VatTaxType,
    AssetMovementType
  }
  alias CyberCore.SAFT.Nomenclatures # New alias

  @nomenclatures [
    %{
      id: "invoice_types",
      name: "Видове фактури",
      description: "Кодове за типове фактури и документи по ЗДДС",
      module: InvoiceType,
      columns: [:code, :name_bg, :name_en]
    },
    %{
      id: "payment_methods",
      name: "Методи на плащане",
      description: "Методи и механизми за плащане",
      module: PaymentMethod,
      columns: [:code, :type, :name_bg, :name_en]
    },
    %{
      id: "stock_movements",
      name: "Движение на запаси",
      description: "Типове движения на материални запаси",
      module: StockMovementType,
      columns: [:code, :name_bg, :name_en]
    },
    %{
      id: "inventory_types",
      name: "Видове запаси",
      description: "Класификация на материалните запаси",
      module: InventoryType,
      columns: [:code, :name_bg, :name_en]
    },
    %{
      id: "vat_tax_types",
      name: "ДДС режими",
      description: "Данъчни режими по отношение на ДДС",
      module: VatTaxType,
      columns: [:code, :name_bg, :name_en]
    },
    %{
      id: "asset_movements",
      name: "Движение на активи",
      description: "Типове транзакции с дълготрайни активи",
      module: AssetMovementType,
      columns: [:code, :short, :name_bg, :name_en]
    },
    %{ # New entry for NC8 TARIC codes
      id: "nc8_taric",
      name: "КН ТАРИК Кодове 2026",
      description: "Комбинирана номенклатура (за SAF-T и Интрастат)",
      module: CyberCore.SAFT.Nomenclatures,
      columns: [:code, :description_bg, :primary_unit, :secondary_unit],
      importable: true
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    first_nom = List.first(@nomenclatures)

    socket =
      socket
      |> assign(:page_title, "SAF-T Номенклатури")
      |> assign(:nomenclatures, @nomenclatures)
      |> assign(:active_tab, first_nom.id)
      |> assign(:search, "")
      |> load_active_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:search, "")
      |> load_active_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign(:search, search)
      |> load_active_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("import_nc8_taric", %{"year" => year_str}, socket) do
    year = String.to_integer(year_str)
    tenant_id = socket.assigns.current_user.tenant_id

    socket =
      case Nomenclatures.import_nc8_taric_codes(tenant_id, year) do
        {:ok, message} ->
          socket
          |> put_flash(:info, message)
          |> load_active_data()

        {:error, message} ->
          put_flash(socket, :error, message)
      end

    {:noreply, socket}
  end

  defp load_active_data(socket) do
    nom = Enum.find(@nomenclatures, &(&1.id == socket.assigns.active_tab))
    search = socket.assigns[:search] || ""
    tenant_id = socket.assigns.current_user.tenant_id

    data =
      case nom.id do
        "nc8_taric" ->
          Nomenclatures.list_nc8_taric_codes(tenant_id)
        _ ->
          if function_exported?(nom.module, :all, 1) do
            apply(nom.module, :all, [tenant_id])
          else
            apply(nom.module, :all, [])
          end
      end
      |> filter_data(search)

    socket
    |> assign(:active_nomenclature, nom)
    |> assign(:data, data)
  end

  defp filter_data(data, ""), do: data

  defp filter_data(data, search) do
    search_lower = String.downcase(search)

    Enum.filter(data, fn item ->
      item
      |> Map.values()
      |> Enum.any?(fn val ->
        val
        |> to_string()
        |> String.downcase()
        |> String.contains?(search_lower)
      end)
    end)
  end

  defp column_header(col) do
    case col do
      :code -> "Код"
      :name_bg -> "Наименование (БГ)"
      :name_en -> "Name (EN)"
      :description_bg -> "Описание"
      :short -> "Съкращение"
      :type -> "Тип"
      :primary_unit -> "Осн. мярка"
      :secondary_unit -> "Доп. мярка"
      _ -> to_string(col)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">SAF-T Номенклатури</h1>
          <p class="mt-2 text-sm text-gray-600">
            Стандартни номенклатури за SAF-T България V 1.0.1
          </p>
        </div>
      </div>

      <div class="flex gap-6">
        <!-- Sidebar with tabs -->
        <div class="w-64 flex-shrink-0">
          <nav class="space-y-1">
            <%= for nom <- @nomenclatures do %>
              <button
                phx-click="change_tab"
                phx-value-tab={nom.id}
                class={[
                  "w-full text-left px-4 py-3 rounded-lg transition-all",
                  if(@active_tab == nom.id,
                    do: "bg-indigo-50 border-l-4 border-indigo-600 text-indigo-700",
                    else: "hover:bg-gray-50 text-gray-700"
                  )
                ]}
              >
                <div class="font-medium"><%= nom.name %></div>
                <div class="text-xs text-gray-500 mt-1"><%= nom.description %></div>
              </button>
            <% end %>
          </nav>
        </div>

        <!-- Main content -->
        <div class="flex-1">
          <div class="bg-white rounded-lg shadow">
            <!-- Search -->
            <div class="px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-medium text-gray-900">
                  <%= @active_nomenclature.name %>
                </h2>
                <div class="flex items-center gap-4">
                  <%= if Map.get(@active_nomenclature, :importable) do %>
                    <button
                      type="button"
                      phx-click="import_nc8_taric"
                      phx-value-year="2026"
                      data-confirm="Ще бъдат импортирани КН кодовете за 2026. Продължи?"
                      class="inline-flex items-center rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-500"
                    >
                      <svg class="mr-1.5 h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                      </svg>
                      Импорт КН 2026
                    </button>
                  <% end %>
                  <span class="text-sm text-gray-500">
                    <%= length(@data) %> записа
                  </span>
                  <div class="relative">
                    <input
                      type="text"
                      name="search"
                      value={@search}
                      phx-keyup="search"
                      phx-debounce="300"
                      placeholder="Търсене..."
                      class="block w-64 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    />
                    <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                      <svg class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Table -->
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <%= for col <- @active_nomenclature.columns do %>
                      <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        <%= column_header(col) %>
                      </th>
                    <% end %>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for item <- @data do %>
                    <tr class="hover:bg-gray-50">
                      <%= for col <- @active_nomenclature.columns do %>
                        <td class={[
                          "px-6 py-4 text-sm",
                          if(col == :code, do: "font-mono font-semibold text-indigo-600", else: "text-gray-900")
                        ]}>
                          <%= Map.get(item, col, "-") %>
                        </td>
                      <% end %>
                    </tr>
                  <% end %>

                  <%= if Enum.empty?(@data) do %>
                    <tr>
                      <td colspan={length(@active_nomenclature.columns)} class="px-6 py-12 text-center text-gray-500">
                        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <p class="mt-2">Няма намерени резултати</p>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Info box -->
          <div class="mt-6 bg-blue-50 rounded-lg p-4 border border-blue-200">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-blue-800">За SAF-T номенклатурите</h3>
                <div class="mt-2 text-sm text-blue-700">
                  <p>
                    Тези номенклатури са съгласно Българската SAF-T схема версия 1.0.1.
                    Използват се при генериране на SAF-T XML файлове за подаване към НАП.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
