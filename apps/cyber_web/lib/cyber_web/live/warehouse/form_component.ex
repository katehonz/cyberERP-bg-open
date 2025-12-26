defmodule CyberWeb.Warehouse.FormComponent do
  use CyberWeb, :live_component

  alias Phoenix.LiveView.JS
  alias CyberCore.Inventory

  def mount(socket) do
    {:ok,
     socket
     |> assign(:warehouse, nil)
     |> assign(:form, nil)}
  end

  def update(assigns, socket) do
    warehouse = assigns.payload["warehouse"] || %Inventory.Warehouse{}
    changeset = Inventory.change_warehouse(warehouse)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:warehouse, warehouse)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"warehouse" => warehouse_params}, socket) do
    warehouse_params = Map.put(warehouse_params, "tenant_id", 1)

    case save_warehouse(socket.assigns.warehouse, warehouse_params) do
      {:ok, warehouse} ->
        send(self(), {:hide_modal, socket.id})
        if socket.assigns.warehouse && socket.assigns.warehouse.id do
          send(socket.assigns.parent, {:warehouse_updated, warehouse})
        else
          send(socket.assigns.parent, {:warehouse_created, warehouse})
        end
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_warehouse(%{id: nil}, attrs), do: Inventory.create_warehouse(attrs)
  defp save_warehouse(warehouse, attrs), do: Inventory.update_warehouse(warehouse, attrs)

  def render(assigns) do
    ~H"""
    <.modal id={@id} show on_cancel={JS.push("hide_modal", to: "##{@id}")}>
      <h2 class="text-lg font-semibold text-gray-900">
        <%= if @warehouse && @warehouse.id, do: "Редакция на склад", else: "Нов склад" %>
      </h2>

      <.simple_form
        for={@form}
        id={"warehouse-form-#{@id}"}
        phx-target={@myself}
        phx-submit="save"
        class="mt-6 space-y-6"
      >
        <.input field={@form[:code]} label="Код" />
        <.input field={@form[:name]} label="Име" />
        <.input
          field={@form[:costing_method]}
          type="select"
          label="Метод за оценка на запасите"
          options={[
            {"Средно претеглена цена", "weighted_average"},
            {"FIFO (Първа входяща, първа изходяща)", "fifo"},
            {"LIFO (Последна входяща, първа изходяща)", "lifo"}
          ]}
        />
        <.input field={@form[:is_active]} type="checkbox" label="Активен" />

        <:actions>
          <.button type="submit">Запази</.button>
          <button type="button" class="text-sm text-gray-500 hover:text-gray-700" phx-click="hide_modal" phx-target={"##{@id}"}>
            Отказ
          </button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end
end
