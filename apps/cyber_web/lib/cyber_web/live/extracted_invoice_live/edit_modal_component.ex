defmodule CyberWeb.ExtractedInvoiceLive.EditModalComponent do
  use CyberWeb, :live_component

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:current_index, assigns.current_index)
      |> assign(:total_count, length(assigns.invoices))

    # TODO: Implement load_products()
    # TODO: Implement load_contacts()

    {:ok, socket}
  end

  def handle_event("navigate", %{"direction" => "next"}, socket) do
    new_index = min(socket.assigns.current_index + 1, socket.assigns.total_count - 1)
    send(self(), {:update_modal_index, new_index})
    {:noreply, socket}
  end

  def handle_event("navigate", %{"direction" => "prev"}, socket) do
    new_index = max(socket.assigns.current_index - 1, 0)
    send(self(), {:update_modal_index, new_index})
    {:noreply, socket}
  end

  def handle_event("add_line", _params, socket) do
    # Добави нов line item
    {:noreply, socket}
  end

  def handle_event("remove_line", %{"index" => index}, socket) do
    # Премахни line item
    {:noreply, socket}
  end

  def handle_event("save", params, socket) do
    # Запази промените
    send(self(), {:save_invoice, params})
    {:noreply, socket}
  end

  def handle_event("approve", params, socket) do
    # Одобри и създай фактура
    send(self(), {:approve_and_convert, params})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <!-- Overlay -->
      <div class="fixed inset-0 bg-black bg-opacity-50" phx-click="close_modal"></div>

      <!-- Modal Content -->
      <div class="relative min-h-screen flex items-center justify-center p-4">
        <div class="relative bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden">

          <!-- Header with navigation -->
          <div class="bg-gradient-to-r from-indigo-600 to-purple-600 text-white p-4 flex justify-between items-center">
            <button phx-click="navigate" phx-value-direction="prev" disabled={@current_index == 0}
              class="px-3 py-1 rounded hover:bg-white/20 disabled:opacity-50">
              ← Назад
            </button>
            <h3 class="text-lg font-semibold">
              Фактура <%= @current_index + 1 %> / <%= @total_count %>
            </h3>
            <button phx-click="navigate" phx-value-direction="next"
              disabled={@current_index == @total_count - 1}
              class="px-3 py-1 rounded hover:bg-white/20 disabled:opacity-50">
              Напред →
            </button>
          </div>

          <!-- Body with form -->
          <div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
            <form phx-submit="save" phx-target={@myself}>
              <!-- Invoice fields here -->
              <%# TODO: Implement render_invoice_form(assigns) %>
            </form>
          </div>

          <!-- Footer with actions -->
          <div class="bg-gray-50 px-6 py-4 flex justify-between border-t">
            <button phx-click="close_modal" class="px-4 py-2 text-gray-700 border rounded hover:bg-gray-100">
              ❌ Отказ
            </button>
            <div class="flex gap-2">
              <button phx-click="save" phx-target={@myself}
                class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
                💾 Съхрани
              </button>
              <button phx-click="approve" phx-target={@myself}
                class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">
                ✅ Одобри
              </button>
            </div>
          </div>

        </div>
      </div>
    </div>
    """
  end
end
