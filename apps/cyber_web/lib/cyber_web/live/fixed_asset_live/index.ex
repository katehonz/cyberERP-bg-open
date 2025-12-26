defmodule CyberWeb.FixedAssetLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounting.FixedAssets
  alias CyberCore.Accounting.Asset
  alias Phoenix.LiveView.JS

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Дълготрайни активи")
     |> assign(:tenant_id, @tenant_id)
     |> assign(:assets, [])
     |> assign(:status_filter, "all")
     |> assign(:tax_category_filter, "all")
     |> assign(:search_query, "")
     |> assign(:statistics, nil)
     |> assign(:selected_year, Date.utc_today().year)
     |> load_assets()
     |> load_statistics()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Дълготрайни активи")
    |> assign(:asset, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нов дълготраен актив")
    |> assign(:asset, %Asset{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    asset =
      FixedAssets.get_asset!(@tenant_id, id, [
        :supplier,
        :accounting_account,
        :expense_account,
        :accumulated_depreciation_account
      ])

    socket
    |> assign(:page_title, "Редактиране на актив")
    |> assign(:asset, asset)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    asset =
      FixedAssets.get_asset!(@tenant_id, id, [
        :supplier,
        :accounting_account,
        :expense_account,
        :accumulated_depreciation_account
      ])

    socket
    |> assign(:page_title, "Детайли на актив")
    |> assign(:asset, asset)
  end

  defp apply_action(socket, :schedule, %{"id" => id}) do
    asset = FixedAssets.get_asset!(@tenant_id, id, [:depreciation_schedule])

    socket
    |> assign(:page_title, "График за амортизация")
    |> assign(:asset, asset)
    |> assign(:depreciation_schedule, asset.depreciation_schedule)
  end

  defp apply_action(socket, :increase_value, %{"id" => id}) do
    asset = FixedAssets.get_asset!(@tenant_id, id, [:supplier, :accounting_account])

    socket
    |> assign(:page_title, "Увеличаване на стойността")
    |> assign(:asset, asset)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    asset = FixedAssets.get_asset!(@tenant_id, id)

    case FixedAssets.delete_asset(asset) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Активът беше изтрит успешно")
         |> load_assets()
         |> load_statistics()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при изтриване на актива")}
    end
  end

  def handle_event("select_year", %{"value" => year}, socket) do
    {:noreply, assign(socket, :selected_year, String.to_integer(year))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> load_assets()}
  end

  def handle_event("filter_tax_category", %{"category" => category}, socket) do
    {:noreply,
     socket
     |> assign(:tax_category_filter, category)
     |> load_assets()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_assets()}
  end

  def handle_event("generate_schedule", %{"id" => id}, socket) do
    asset = FixedAssets.get_asset!(@tenant_id, id)

    case FixedAssets.generate_depreciation_schedule(asset) do
      {:ok, _schedules} ->
        {:noreply,
         socket
         |> put_flash(:info, "Графикът за амортизация беше генериран успешно")
         |> load_assets()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при генериране на график")}
    end
  end

  def handle_event("post_current_month", _params, socket) do
    # Get current period (first day of current month)
    period_date = Date.beginning_of_month(Date.utc_today())

    case FixedAssets.post_period_depreciation(@tenant_id, period_date) do
      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Успешно постнати #{count} записа за амортизация за #{Calendar.strftime(period_date, "%B %Y")}"
         )
         |> load_assets()
         |> load_statistics()}

      {:error, failures} ->
        error_msg = "Грешка при постване на амортизация: #{length(failures)} записа се провалиха"

        {:noreply,
         socket
         |> put_flash(:error, error_msg)}
    end
  end

  defp load_assets(socket) do
    opts = build_filter_opts(socket)

    assets =
      FixedAssets.list_assets(@tenant_id, opts ++ [preload: [:supplier, :accounting_account]])

    assign(socket, :assets, assets)
  end

  defp load_statistics(socket) do
    stats = FixedAssets.get_assets_statistics(@tenant_id)
    assign(socket, :statistics, stats)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:status, filter_value(socket.assigns.status_filter))
    |> maybe_put(:tax_category, filter_value(socket.assigns.tax_category_filter))
    |> maybe_put(:search, socket.assigns.search_query)
  end

  defp filter_value("all"), do: nil
  defp filter_value(value), do: value

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp status_badge("active"), do: "emerald"
  defp status_badge("disposed"), do: "red"
  defp status_badge("fully_depreciated"), do: "amber"
  defp status_badge(_), do: "zinc"

  defp status_label("active"), do: "Активен"
  defp status_label("inactive"), do: "Неактивен"
  defp status_label("disposed"), do: "Изведен"
  defp status_label("fully_depreciated"), do: "Амортизиран"
  defp status_label(_), do: "Неизвестен"

  defp tax_category_label(category) do
    case Asset.tax_category_info(category) do
      %{name: name} -> "#{category} - #{name}"
      _ -> category || "-"
    end
  end

  defp format_currency(amount) when is_nil(amount), do: "0.00 лв."

  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_currency_string()
  end

  defp format_currency(amount) when is_number(amount) do
    amount
    |> Decimal.from_float()
    |> format_currency()
  end

  defp format_currency_string(str) do
    # Add thousand separators
    [int_part, dec_part] = String.split(str <> ".00", ".") |> Enum.take(2)

    formatted_int =
      int_part
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(" ")
      |> String.reverse()

    "#{formatted_int}.#{String.pad_trailing(dec_part, 2, "0")} лв."
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <!-- Flash Messages -->
      <.flash_group flash={@flash} />

      <!-- Page Header -->
      <div class="mb-8">
        <div class="sm:flex sm:items-center sm:justify-between">
          <div>
            <h1 class="text-3xl font-bold text-zinc-900">Дълготрайни материални активи (ДМА)</h1>
            <p class="mt-2 text-sm text-zinc-600">Управление на дълготрайни активи и амортизация</p>
          </div>
          <div class="mt-4 flex flex-wrap items-center gap-3 sm:mt-0">
            <!-- SAF-T Export -->
            <div class="flex items-center gap-2">
              <select
                id="saft-year"
                class="rounded-lg border-zinc-300 text-sm"
                phx-change="select_year"
              >
                <%= for year <- (@selected_year - 3)..(@selected_year + 1) do %>
                  <option value={year} selected={year == @selected_year}><%= year %></option>
                <% end %>
              </select>
              <a
                href={~p"/api/accounting/assets-export-saft/#{@selected_year}"}
                class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-blue-700"
                download
              >
                <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
                Експорт SAF-T
              </a>
            </div>

            <div class="h-6 w-px bg-zinc-300"></div>

            <button
              type="button"
              class="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700"
              phx-click="post_current_month"
              data-confirm="Сигурни ли сте, че искате да постнете амортизация за текущия месец?"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Постни за текущ месец
            </button>
            <.link
              patch={~p"/fixed-assets/new"}
              class="inline-flex items-center gap-2 rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Нов актив
            </.link>
          </div>
        </div>
      </div>

      <!-- Statistics Cards -->
      <%= if @statistics do %>
        <div class="mb-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0 rounded-lg bg-indigo-100 p-3">
                  <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
                  </svg>
                </div>
                <div class="ml-5">
                  <dt class="text-sm font-medium text-zinc-500">Общо активи</dt>
                  <dd class="mt-1 text-3xl font-semibold text-zinc-900"><%= @statistics.total_count %></dd>
                </div>
              </div>
            </div>
          </div>

          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0 rounded-lg bg-emerald-100 p-3">
                  <svg class="h-6 w-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div class="ml-5">
                  <dt class="text-sm font-medium text-zinc-500">Активни</dt>
                  <dd class="mt-1 text-3xl font-semibold text-zinc-900"><%= @statistics.active_count %></dd>
                </div>
              </div>
            </div>
          </div>

          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0 rounded-lg bg-blue-100 p-3">
                  <svg class="h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div class="ml-5">
                  <dt class="text-sm font-medium text-zinc-500">Обща стойност</dt>
                  <dd class="mt-1 text-2xl font-semibold text-zinc-900"><%= format_currency(@statistics.total_acquisition_cost) %></dd>
                </div>
              </div>
            </div>
          </div>

          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0 rounded-lg bg-amber-100 p-3">
                  <svg class="h-6 w-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
                  </svg>
                </div>
                <div class="ml-5">
                  <dt class="text-sm font-medium text-zinc-500">Балансова стойност</dt>
                  <dd class="mt-1 text-2xl font-semibold text-zinc-900"><%= format_currency(@statistics.total_book_value) %></dd>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Assets Table -->
      <div class="overflow-hidden bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-200">
              <thead>
                <tr>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Код</th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Наименование</th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Категория ЗКПО</th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Стойност</th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Дата</th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-zinc-900">Статус</th>
                  <th class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                    <span class="sr-only">Действия</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-200">
                <%= for asset <- @assets do %>
                  <tr class="hover:bg-zinc-50">
                    <td class="whitespace-nowrap px-3 py-4 text-sm font-medium text-zinc-900">
                      <%= asset.code %>
                    </td>
                    <td class="px-3 py-4 text-sm text-zinc-900">
                      <div class="font-medium"><%= asset.name %></div>
                      <%= if asset.inventory_number do %>
                        <div class="text-zinc-500">Инв. № <%= asset.inventory_number %></div>
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-zinc-500">
                      <%= tax_category_label(asset.tax_category) %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-zinc-900">
                      <%= format_currency(asset.acquisition_cost) %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-zinc-500">
                      <%= Calendar.strftime(asset.acquisition_date, "%d.%m.%Y") %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm">
                      <span class={"inline-flex rounded-full px-2 text-xs font-semibold leading-5 bg-#{status_badge(asset.status)}-100 text-#{status_badge(asset.status)}-800"}>
                        <%= status_label(asset.status) %>
                      </span>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <div class="flex justify-end gap-3">
                        <.link patch={~p"/fixed-assets/#{asset.id}"} class="text-indigo-600 hover:text-indigo-900">
                          Преглед
                        </.link>
                        <.link patch={~p"/fixed-assets/#{asset.id}/edit"} class="text-indigo-600 hover:text-indigo-900">
                          Редактирай
                        </.link>
                        <%= if asset.status == "active" do %>
                          <.link patch={~p"/fixed-assets/#{asset.id}/increase-value"} class="text-emerald-600 hover:text-emerald-900">
                            + Стойност
                          </.link>
                        <% end %>
                        <.link patch={~p"/fixed-assets/#{asset.id}/schedule"} class="text-indigo-600 hover:text-indigo-900">
                          График
                        </.link>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <%= if @live_action in [:new, :edit] do %>
      <.modal id="asset-modal" show on_cancel={JS.patch(~p"/fixed-assets")}>
        <.live_component
          module={CyberWeb.FixedAssetLive.FormComponent}
          id={@asset.id || :new}
          title={@page_title}
          action={@live_action}
          asset={@asset}
          tenant_id={@tenant_id}
          patch={~p"/fixed-assets"}
        />
      </.modal>
    <% end %>

    <%= if @live_action == :show && @asset do %>
      <.modal id="show-modal" show on_cancel={JS.patch(~p"/fixed-assets")}>
        <.live_component
          module={CyberWeb.FixedAssetLive.ShowComponent}
          id={"show-#{@asset.id}"}
          asset={@asset}
          patch={~p"/fixed-assets"}
        />
      </.modal>
    <% end %>

    <%= if @live_action == :schedule && @asset do %>
      <.modal id="schedule-modal" show on_cancel={JS.patch(~p"/fixed-assets")}>
        <.live_component
          module={CyberWeb.FixedAssetLive.ScheduleComponent}
          id={"schedule-#{@asset.id}"}
          asset={@asset}
          depreciation_schedule={@depreciation_schedule}
          patch={~p"/fixed-assets"}
        />
      </.modal>
    <% end %>

    <%= if @live_action == :increase_value && @asset do %>
      <.modal id="increase-value-modal" show on_cancel={JS.patch(~p"/fixed-assets")}>
        <.live_component
          module={CyberWeb.FixedAssetLive.IncreaseValueComponent}
          id={"increase-value-#{@asset.id}"}
          asset={@asset}
          tenant_id={@tenant_id}
          patch={~p"/fixed-assets"}
        />
      </.modal>
    <% end %>
    """
  end
end
