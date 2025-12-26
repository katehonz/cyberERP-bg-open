defmodule CyberWeb.CurrencyLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Currencies

  @impl true
  def mount(_params, _session, socket) do
    currencies = Currencies.list_currencies()

    socket =
      socket
      |> assign(:currencies, currencies)
      |> assign(:page_title, "Валути")
      |> assign(:updating_rates, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_bnb_rates", _params, socket) do
    socket = assign(socket, :updating_rates, true)

    case Currencies.update_bnb_rates_today() do
      {:ok, count} ->
        socket =
          socket
          |> put_flash(:info, "Успешно обновени #{count} курса от БНБ")
          |> assign(:currencies, Currencies.list_currencies())
          |> assign(:updating_rates, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Грешка при обновяване на курсове: #{inspect(reason)}")
          |> assign(:updating_rates, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_ecb_rates", _params, socket) do
    socket = assign(socket, :updating_rates, true)

    case Currencies.update_ecb_rates_today() do
      {:ok, count} ->
        socket =
          socket
          |> put_flash(:info, "Успешно обновени #{count} курса от ЕЦБ")
          |> assign(:currencies, Currencies.list_currencies())
          |> assign(:updating_rates, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Грешка при обновяване на курсове: #{inspect(reason)}")
          |> assign(:updating_rates, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_all_rates", _params, socket) do
    socket = assign(socket, :updating_rates, true)

    case Currencies.update_all_rates_today() do
      {:ok, %{bnb: bnb_count, ecb: ecb_count, total: total}} ->
        socket =
          socket
          |> put_flash(
            :info,
            "Успешно обновени #{total} курса (БНБ: #{bnb_count}, ЕЦБ: #{ecb_count})"
          )
          |> assign(:currencies, Currencies.list_currencies())
          |> assign(:updating_rates, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Грешка при обновяване на курсове: #{inspect(reason)}")
          |> assign(:updating_rates, false)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Валути</h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък с всички валути в системата и техните настройки.
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none space-x-2">
          <button
            type="button"
            phx-click="update_bnb_rates"
            disabled={@updating_rates}
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50"
          >
            <%= if @updating_rates, do: "Обновяване...", else: "Обнови БНБ" %>
          </button>
          <button
            type="button"
            phx-click="update_ecb_rates"
            disabled={@updating_rates}
            class="rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-green-600 disabled:opacity-50"
          >
            <%= if @updating_rates, do: "Обновяване...", else: "Обнови ЕЦБ" %>
          </button>
          <button
            type="button"
            phx-click="update_all_rates"
            disabled={@updating_rates}
            class="rounded-md bg-purple-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600 disabled:opacity-50"
          >
            <%= if @updating_rates, do: "Обновяване...", else: "Обнови всички" %>
          </button>
        </div>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Код
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Наименование
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Символ
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Дес. места
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      БНБ код
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Статус
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Базова
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for currency <- @currencies do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= currency.code %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= currency.name_bg %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= currency.symbol %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= currency.decimal_places %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= currency.bnb_code || "-" %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <span class={[
                          "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                          if(currency.is_active,
                            do: "bg-green-100 text-green-800",
                            else: "bg-red-100 text-red-800"
                          )
                        ]}>
                          <%= if currency.is_active, do: "Активна", else: "Неактивна" %>
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if currency.is_base_currency do %>
                          <span class="inline-flex rounded-full bg-blue-100 px-2 text-xs font-semibold leading-5 text-blue-800">
                            Базова
                          </span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8 rounded-lg bg-blue-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <h3 class="text-sm font-medium text-blue-800">Информация за валутните курсове</h3>
            <div class="mt-2 text-sm text-blue-700">
              <p>
                БНБ: Българска народна банка - официални курсове за България<br />
                ЕЦБ: Европейска централна банка - подготовка за Еврозоната 2026<br />
                Курсовете се обновяват автоматично на работни дни около 16:00 CET
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
