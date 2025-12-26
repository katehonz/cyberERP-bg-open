defmodule CyberWeb.PriceListLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Sales.PriceLists
  alias CyberCore.Sales.PriceList
  alias CyberCore.Currencies

  @tenant_id 1

  @impl true
  def update(%{price_list: price_list} = assigns, socket) do
    changeset = PriceList.changeset(price_list, %{})
    currencies = Currencies.list_currencies()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))
     |> assign(:currencies, currencies)}
  end

  @impl true
  def handle_event("validate", %{"price_list" => price_list_params}, socket) do
    changeset =
      socket.assigns.price_list
      |> PriceList.changeset(price_list_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"price_list" => price_list_params}, socket) do
    save_price_list(socket, socket.assigns.action, price_list_params)
  end

  defp save_price_list(socket, :edit, price_list_params) do
    case PriceLists.update_price_list(socket.assigns.price_list, price_list_params) do
      {:ok, _price_list} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ценовата листа е обновена успешно.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_price_list(socket, :new, price_list_params) do
    case PriceLists.create_price_list(Map.put(price_list_params, "tenant_id", @tenant_id)) do
      {:ok, _price_list} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ценовата листа е създадена успешно.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-zinc-900"><%= @title %></h2>
        <p class="text-sm text-zinc-600 mt-1">Използвайте формата по-долу за да управлявате ценовата листа.</p>
      </div>

      <.simple_form
        for={@form}
        id="price-list-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Име" required />
        <.input field={@form[:type]} type="select" label="Тип" options={[{"Стандартна", "non_retail"}, {"На дребно", "retail"}]} />
        <.input field={@form[:currency_id]} type="select" label="Валута" prompt="-- Изберете валута --" options={Enum.map(@currencies, fn c -> {c.name_bg || c.code, c.id} end)} />

        <:actions>
          <.button phx-disable-with="Запазване...">Запази</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
