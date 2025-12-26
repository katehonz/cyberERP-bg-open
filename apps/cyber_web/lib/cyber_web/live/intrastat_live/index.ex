defmodule CyberWeb.IntrastatLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Intrastat

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Интрастат Декларации")
     |> assign(:year, Date.utc_today().year)
     |> assign(:month, Date.utc_today().month)
     |> assign(:declaration, nil)
     |> assign(:lines, [])
     |> assign(:type, "arrivals")
     |> assign(:tenant_id, 1) # Add tenant_id here
     |> load_declaration()}
  end

  defp load_declaration(socket) do
    type = to_string(socket.assigns.type) # Ensure it's a string
    declaration = Intrastat.get_declaration(socket.assigns.tenant_id, socket.assigns.year, socket.assigns.month, type)
    lines = if declaration, do: Intrastat.list_declaration_lines(declaration.id), else: []

    socket
    |> assign(:declaration, declaration)
    |> assign(:lines, lines)
  end

  @impl true
  def handle_event("show", %{"year" => year, "month" => month, "type" => type}, socket) do
    socket =
      socket
      |> assign(:year, String.to_integer(year))
      |> assign(:month, String.to_integer(month))
      |> assign(:type, type)
      |> load_declaration()

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate", _params, socket) do
    tenant_id = socket.assigns.tenant_id
    year = socket.assigns.year
    month = socket.assigns.month
    type = to_string(socket.assigns.type) # Ensure it's a string for the backend

    case Intrastat.generate_declarations(tenant_id, year, month, type) do
      {:ok, _declaration} ->
        {:noreply, socket |> put_flash(:info, "Декларацията беше генерирана успешно.") |> load_declaration()}
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Грешка при генериране: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Интрастат Декларации</h1>
          <p class="mt-2 text-sm text-gray-700">
            Преглед и генериране на Интрастат декларации.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button
            phx-click="generate"
            phx-disable-with="Генериране..."
            class="inline-flex items-center justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Генерирай
          </button>
        </div>
      </div>

      <!-- Филтри -->
      <form phx-change="show" class="mt-6 flex items-end gap-4">
        <div>
          <label for="year" class="block text-sm font-medium text-gray-700">Година</label>
          <select
            name="year"
            id="year"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <%= for y <- [2025, 2024, 2023] do %>
              <option value={y} selected={y == @year}><%= y %></option>
            <% end %>
          </select>
        </div>
        <div>
          <label for="month" class="block text-sm font-medium text-gray-700">Месец</label>
          <select
            name="month"
            id="month"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <%= for m <- 1..12 do %>
              <option value={m} selected={m == @month}><%= m %></option>
            <% end %>
          </select>
        </div>
        <div>
          <label for="type" class="block text-sm font-medium text-gray-700">Тип</label>
          <select
            name="type"
            id="type"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          >
            <option value="arrivals" selected={"arrivals" == @type}>Пристигания</option>
            <option value="dispatches" selected={"dispatches" == @type}>Изпращания</option>
          </select>
        </div>
      </form>

      <!-- Таблица -->
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <%= if @lines != [] do %>
                <table class="min-w-full divide-y divide-gray-300">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                        Код по КН
                      </th>
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                        Държава партньор
                      </th>
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                        Произход
                      </th>
                      <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                        Вид сделка
                      </th>
                      <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                        Стойност
                      </th>
                      <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                        Нето тегло (кг)
                      </th>
                      <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                        Количество
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                    <%= for line <- @lines do %>
                      <tr class="hover:bg-gray-50">
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                          <%= line.commodity_code %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          <%= line.partner_member_state %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          <%= line.country_of_origin %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          <%= line.transaction_nature %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                          <%= line.invoiced_value %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                          <%= line.net_mass %>
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                          <%= line.supplementary_unit %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              <% else %>
                <div class="text-center py-12">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">
                    Няма данни за избрания период
                  </h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Променете филтрите или генерирайте нова декларация.
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end