defmodule CyberWeb.PriceListLive.Index do
  use CyberWeb, :live_view

  alias Phoenix.LiveView.JS
  alias CyberCore.Sales.PriceLists
  alias CyberCore.Sales.PriceList

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Ценови Листи")
     |> assign(:price_list, nil)
     |> assign(:price_lists, PriceLists.list_price_lists(@tenant_id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Редактиране на Ценова Листа")
    |> assign(:price_list, PriceLists.get_price_list!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Нова Ценова Листа")
    |> assign(:price_list, %PriceList{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Ценови Листи")
    |> assign(:price_list, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    price_list = PriceLists.get_price_list!(id)
    {:ok, _} = PriceLists.delete_price_list(price_list)

    {:noreply, assign(socket, :price_lists, PriceLists.list_price_lists(@tenant_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
          <p class="mt-1 text-sm text-gray-600">
            Управление на ценови листи
          </p>
        </div>
        <.link
          patch={~p"/price-lists/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нова ценова листа
        </.link>
      </div>

      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Име
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Тип
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">
                Действия
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for price_list <- @price_lists do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm font-medium text-gray-900">
                  <.link navigate={~p"/price-lists/#{price_list.id}"} class="hover:underline">
                    <%= price_list.name %>
                  </.link>
                </td>
                <td class="px-4 py-3 text-sm text-gray-500">
                  <%= price_list.type %>
                </td>
                <td class="px-4 py-3 text-right text-sm space-x-3">
                  <.link
                    navigate={~p"/price-lists/#{price_list.id}"}
                    class="text-green-600 hover:text-green-700 font-medium"
                  >
                    Цени
                  </.link>
                  <.link
                    patch={~p"/price-lists/#{price_list}/edit"}
                    class="text-indigo-600 hover:text-indigo-700"
                  >
                    Редакция
                  </.link>
                  <a
                    href="#"
                    phx-click="delete"
                    phx-value-id={price_list.id}
                    data-confirm="Сигурни ли сте?"
                    class="text-red-600 hover:text-red-700"
                  >
                    Изтрий
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <%= if @live_action in [:new, :edit] do %>
      <.modal id="price-list-modal" show on_cancel={JS.patch(~p"/price-lists")}>
        <.live_component
          module={CyberWeb.PriceListLive.FormComponent}
          id={@price_list.id || :new}
          title={@page_title}
          action={@live_action}
          price_list={@price_list}
          patch={~p"/price-lists"}
        />
      </.modal>
    <% end %>
    """
  end
end
