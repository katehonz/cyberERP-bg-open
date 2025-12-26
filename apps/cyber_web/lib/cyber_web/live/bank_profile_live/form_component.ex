defmodule CyberWeb.BankProfileLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Repo
  alias CyberCore.Bank.BankProfile
  alias CyberCore.Accounting

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-2">
        <%= @title %>
      </h2>
      <p class="text-sm text-gray-600 mb-4">
        Конфигурация на банкова сметка за синхронизация или ръчен импорт
      </p>

      <.simple_form
        for={@form}
        id="bank-profile-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Име" required />

        <.input field={@form[:iban]} type="text" label="IBAN" />
        <.input field={@form[:bic]} type="text" label="BIC/SWIFT" />
        <.input field={@form[:bank_name]} type="text" label="Име на банката" />

        <.input
          field={@form[:bank_account_id]}
          type="select"
          label="Банкова сметка (счетоводство)"
          options={@account_options}
          required
          prompt="Изберете сметка"
        />

        <.input
          field={@form[:buffer_account_id]}
          type="select"
          label="Буферна сметка (за сверка)"
          options={@account_options}
          required
          prompt="Изберете сметка"
        />

        <.input field={@form[:currency_code]} type="text" label="Валута" placeholder="BGN" required />

        <.input
          field={@form[:import_format]}
          type="select"
          label="Формат за ръчен импорт"
          options={[
            {"MT940", "mt940"},
            {"CAMT.053 (Wise)", "camt053_wise"},
            {"CAMT.053 (Revolut)", "camt053_revolut"},
            {"CAMT.053 (Paysera)", "camt053_paysera"},
            {"ЦКБ CSV", "ccb_csv"},
            {"Пощенска банка XML", "postbank_xml"},
            {"ОББ XML", "obb_xml"}
          ]}
          prompt="Не се използва ръчен импорт"
        />

        <.input
          field={@form[:auto_sync_enabled]}
          type="checkbox"
          label="Автоматична синхронизация (Salt Edge)"
        />

        <:actions>
          <.button phx-disable-with="Записване...">Запази</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{bank_profile: bank_profile} = assigns, socket) do
    changeset = BankProfile.changeset(bank_profile, %{})

    # Load account options
    account_options = load_account_options(assigns.current_tenant_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:account_options, account_options)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"bank_profile" => bank_profile_params}, socket) do
    changeset =
      socket.assigns.bank_profile
      |> BankProfile.changeset(bank_profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"bank_profile" => bank_profile_params}, socket) do
    save_bank_profile(socket, socket.assigns.action, bank_profile_params)
  end

  defp save_bank_profile(socket, :edit, bank_profile_params) do
    case socket.assigns.bank_profile
         |> BankProfile.changeset(bank_profile_params)
         |> Repo.update() do
      {:ok, bank_profile} ->
        notify_parent({:saved, bank_profile})

        {:noreply,
         socket
         |> put_flash(:info, "Банковият профил беше обновен")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_bank_profile(socket, :new, bank_profile_params) do
    bank_profile_params =
      bank_profile_params
      |> Map.put("tenant_id", socket.assigns.current_tenant_id)

    case %BankProfile{}
         |> BankProfile.changeset(bank_profile_params)
         |> Repo.insert() do
      {:ok, bank_profile} ->
        notify_parent({:saved, bank_profile})

        {:noreply,
         socket
         |> put_flash(:info, "Банковият профил беше създаден")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp load_account_options(tenant_id) do
    Accounting.list_accounts(tenant_id)
    |> Enum.map(fn account ->
      {"#{account.code} - #{account.name}", account.id}
    end)
  end
end
