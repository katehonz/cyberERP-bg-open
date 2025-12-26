defmodule CyberWeb.ExchangeRateLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.{Repo, Currencies}
  alias CyberCore.Currencies.ExchangeRate
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    currencies = Currencies.list_currencies(%{is_active: true})
    base_currency = Currencies.get_base_currency!()

    socket =
      socket
      |> assign(:currencies, currencies)
      |> assign(:base_currency, base_currency)
      |> assign(:selected_date, Date.utc_today())
      |> assign(:page_title, "Обменни курсове")
      |> load_rates()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        socket =
          socket
          |> assign(:selected_date, date)
          |> load_rates()

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Невалидна дата")}
    end
  end

  @impl true
  def handle_event("today", _params, socket) do
    socket =
      socket
      |> assign(:selected_date, Date.utc_today())
      |> load_rates()

    {:noreply, socket}
  end

  @impl true
  def handle_event("yesterday", _params, socket) do
    yesterday = Date.add(socket.assigns.selected_date, -1)

    socket =
      socket
      |> assign(:selected_date, yesterday)
      |> load_rates()

    {:noreply, socket}
  end

  @impl true
  def handle_event("tomorrow", _params, socket) do
    tomorrow = Date.add(socket.assigns.selected_date, 1)

    socket =
      socket
      |> assign(:selected_date, tomorrow)
      |> load_rates()

    {:noreply, socket}
  end

  defp load_rates(socket) do
    date = socket.assigns.selected_date
    base_currency = socket.assigns.base_currency

    # Load all rates for the selected date
    rates =
      ExchangeRate
      |> where([r], r.valid_date == ^date)
      |> where([r], r.is_active == true)
      |> preload([:from_currency, :to_currency])
      |> Repo.all()
      |> Enum.group_by(& &1.from_currency_id)

    # Build rate display data
    rate_data =
      socket.assigns.currencies
      |> Enum.reject(& &1.is_base_currency)
      |> Enum.map(fn currency ->
        # Find rate: foreign -> BGN
        rate_to_base =
          Map.get(rates, currency.id, []) |> Enum.find(&(&1.to_currency_id == base_currency.id))

        %{
          currency: currency,
          rate_to_base: rate_to_base,
          is_up_to_date: rate_to_base && ExchangeRate.is_up_to_date?(rate_to_base)
        }
      end)

    assign(socket, :rate_data, rate_data)
  end

  defp format_rate(nil), do: "-"
  defp format_rate(%ExchangeRate{rate: rate}), do: Decimal.to_string(rate, :normal)

  defp format_date(date) do
    Calendar.strftime(date, "%d.%m.%Y")
  end

  defp source_label("bnb"), do: "БНБ"
  defp source_label("ecb"), do: "ЕЦБ"
  defp source_label("manual"), do: "Ръчно"
  defp source_label("api"), do: "API"
  defp source_label(_), do: "-"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Обменни курсове</h1>
          <p class="mt-2 text-sm text-gray-700">
            Валутни курсове спрямо базовата валута (<%= @base_currency.code %>)
          </p>
        </div>
      </div>

      <div class="mt-8 flex items-center space-x-4">
        <button
          type="button"
          phx-click="yesterday"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          ← Предишен ден
        </button>

        <div class="flex items-center space-x-2">
          <input
            type="date"
            value={Date.to_iso8601(@selected_date)}
            phx-change="change_date"
            class="block rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
          />
          <button
            type="button"
            phx-click="today"
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Днес
          </button>
        </div>

        <button
          type="button"
          phx-click="tomorrow"
          class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Следващ ден →
        </button>

        <div class="flex-1"></div>

        <div class="text-sm text-gray-500">
          Избрана дата: <span class="font-semibold"><%= format_date(@selected_date) %></span>
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
                      Валута
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Код
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Курс към <%= @base_currency.code %>
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                      Източник
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                      Статус
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for data <- @rate_data do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= data.currency.name_bg %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= data.currency.code %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-mono">
                        <%= if data.rate_to_base do %>
                          1 <%= data.currency.code %> = <%= format_rate(data.rate_to_base) %> <%= @base_currency.code %>
                        <% else %>
                          <span class="text-gray-400">-</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 text-center">
                        <%= if data.rate_to_base do %>
                          <span class={[
                            "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                            case data.rate_to_base.rate_source do
                              "bnb" -> "bg-blue-100 text-blue-800"
                              "ecb" -> "bg-green-100 text-green-800"
                              "manual" -> "bg-yellow-100 text-yellow-800"
                              _ -> "bg-gray-100 text-gray-800"
                            end
                          ]}>
                            <%= source_label(data.rate_to_base.rate_source) %>
                          </span>
                        <% else %>
                          -
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-center">
                        <%= if data.rate_to_base do %>
                          <span class={[
                            "inline-flex rounded-full px-2 text-xs font-semibold leading-5",
                            if(data.is_up_to_date,
                              do: "bg-green-100 text-green-800",
                              else: "bg-orange-100 text-orange-800"
                            )
                          ]}>
                            <%= if data.is_up_to_date, do: "Актуален", else: "Остарял" %>
                          </span>
                        <% else %>
                          <span class="inline-flex rounded-full bg-red-100 px-2 text-xs font-semibold leading-5 text-red-800">
                            Липсва
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

      <div class="mt-8 rounded-lg bg-yellow-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">Забележка</h3>
            <div class="mt-2 text-sm text-yellow-700">
              <p>
                Курсовете се обновяват автоматично на работни дни. За актуализация използвайте бутоните в страницата "Валути".
                Статус "Остарял" означава, че курсът е по-стар от 1 работен ден.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
