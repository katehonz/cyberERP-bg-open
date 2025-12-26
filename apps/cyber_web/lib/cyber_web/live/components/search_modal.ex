defmodule CyberWeb.Components.SearchModal do
  use CyberWeb, :live_component

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        :if={@show}
        id={@id}
        show
        on_cancel={JS.push("cancel", target: @myself)}
      >
        <div class="p-6">
          <h2 class="text-lg font-bold"><%= @title %></h2>
          <div class="mt-4">
            <form phx-change="search" phx-target={@myself}>
              <input
                type="text"
                name="value"
                value={@search_term}
                placeholder="Търсене..."
                class="w-full rounded-md border-gray-300"
                autofocus
                phx-debounce="300"
              />
            </form>
          </div>
          <div class="mt-4 max-h-96 overflow-y-auto">
            <ul>
              <%= for item <- @results do %>
                <li
                  phx-target={@myself}
                  phx-click="select_item"
                  phx-value-id={item.id}
                  class="cursor-pointer rounded-md p-2 hover:bg-gray-100"
                >
                  <%= for {field, class, format_fun} <- @display_fields do %>
                    <span class={class}><%= format_fun.(Map.get(item, field)) %></span>
                  <% end %>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       show: false,
       title: nil,
       search_term: "",
       results: [],
       search_fun: nil,
       display_fields: [],
       caller: nil,
       field: nil
     )}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("search", %{"value" => term}, socket) do
    results = socket.assigns.search_fun.(term)
    {:noreply, assign(socket, search_term: term, results: results)}
  end

  def handle_event("select_item", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    item = Enum.find(socket.assigns.results, &(&1.id == id))

    send(
      socket.assigns.caller,
      {:search_modal_selected, %{item: item, field: socket.assigns.field}}
    )

    {:noreply, assign(socket, show: false, search_term: "", results: [])}
  end

  def handle_event("cancel", _, socket) do
    send(socket.assigns.caller, {:search_modal_cancelled, %{field: socket.assigns.field}})
    {:noreply, assign(socket, show: false, search_term: "", results: [])}
  end
end
