defmodule CyberWeb.TenantLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">
        <%= @title %>
      </h2>

      <.simple_form
        for={@form}
        id="tenant-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} label="Име на фирмата" required />
        <.input
          field={@form[:slug]}
          label="Slug (за URL)"
          placeholder="moya-firma"
          required
        />
        <p class="mt-1 text-xs text-gray-500">Малки букви, цифри и тирета</p>

        <.input
          field={@form[:base_currency_code]}
          type="select"
          label="Основна валута"
          options={[
            {"BGN - Bulgarian Lev", "BGN"},
            {"EUR - Euro", "EUR"},
            {"USD - US Dollar", "USD"},
            {"GBP - British Pound", "GBP"}
          ]}
          required
        />

        <div class="flex items-center gap-4">
          <.input
            field={@form[:in_eurozone]}
            type="select"
            label="Във еврозоната"
            options={[
              {"Не", "false"},
              {"Да", "true"}
            ]}
          />

          <.input
            field={@form[:eurozone_entry_date]}
            type="date"
            label="Дата на влизане в еврозоната"
          />
        </div>

        <:actions>
          <.button type="submit">Запази</.button>
          <.link patch={@patch} class="text-sm text-gray-500 hover:text-gray-700">
            Отказ
          </.link>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{tenant: tenant} = assigns, socket) do
    changeset = Accounts.change_tenant(tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"tenant" => tenant_params}, socket) do
    changeset =
      socket.assigns.tenant
      |> Accounts.change_tenant(tenant_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"tenant" => tenant_params}, socket) do
    save_tenant(socket, socket.assigns.action, tenant_params)
  end

  defp save_tenant(socket, :edit, tenant_params) do
    case Accounts.update_tenant(socket.assigns.tenant, tenant_params) do
      {:ok, tenant} ->
        notify_parent({:saved, tenant})

        {:noreply,
         socket
         |> put_flash(:info, "Фирмата беше актуализирана успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_tenant(socket, :new, tenant_params) do
    case Accounts.create_tenant(tenant_params) do
      {:ok, tenant} ->
        notify_parent({:saved, tenant})

        {:noreply,
         socket
         |> put_flash(:info, "Фирмата беше създадена успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
