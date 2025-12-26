defmodule CyberWeb.AccountLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting
  import CyberWeb.CoreComponents

  @impl true
  def update(%{account: account} = assigns, socket) do
    changeset = Accounting.change_account(account)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      socket.assigns.account
      |> Accounting.change_account(account_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"account" => account_params}, socket) do
    # Извличаме account_class от първата цифра на кода
    account_params = derive_account_class(account_params)
    save_account(socket, socket.assigns.action, account_params)
  end

  defp derive_account_class(%{"code" => code} = params) when is_binary(code) and code != "" do
    case Integer.parse(code) do
      {num, _} ->
        class = div(num, 100)

        if class >= 1 and class <= 7 do
          Map.put(params, "account_class", class)
        else
          params
        end

      :error ->
        params
    end
  end

  defp derive_account_class(params), do: params

  defp save_account(socket, :edit, account_params) do
    case Accounting.update_account(
           socket.assigns.tenant_id,
           socket.assigns.account,
           account_params
         ) do
      {:ok, account} ->
        notify_parent({:saved, account})

        {:noreply,
         socket
         |> put_flash(:info, "Account updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_account(socket, :new, account_params) do
    case Accounting.create_account(socket.assigns.tenant_id, account_params) do
      {:ok, account} ->
        notify_parent({:saved, account})

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="space-y-4">
        <h2 class="text-2xl font-semibold text-gray-900"><%= @title %></h2>
        <p class="text-sm text-gray-600">
          Използвайте тази форма, за да управлявате сметки.
        </p>
      </div>

      <.simple_form
        for={@form}
        id="account-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <.input field={@form[:code]} type="text" label="Код" placeholder="напр. 101, 503" />
        <.input field={@form[:name]} type="text" label="Име" />
        <.input field={@form[:standard_code]} type="text" label="Стандартен код (SAF-T)" placeholder="напр. 101, 503" />

        <.input
          field={@form[:account_type]}
          type="select"
          label="Тип на сметката"
          options={[
            {"Актив", :asset},
            {"Пасив", :liability},
            {"Капитал", :equity},
            {"Приход", :revenue},
            {"Разход", :expense}
          ]}
          prompt="Изберете тип"
        />
        <:actions>
          <.button phx-disable-with="Запис...">Запис</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
