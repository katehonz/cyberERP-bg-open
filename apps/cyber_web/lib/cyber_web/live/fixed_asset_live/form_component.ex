defmodule CyberWeb.FixedAssetLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting.{FixedAssets, Asset}
  alias CyberCore.Accounting
  alias CyberCore.Contacts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-zinc-900"><%= @title %></h2>
      </div>

      <.form
        for={@form}
        id="asset-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <!-- Grid layout for form fields -->
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <!-- Left Column -->
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-semibold text-zinc-900 mb-3">Основна информация</h3>

              <div class="space-y-4">
                <div>
                  <.input field={@form[:code]} type="text" label="Код" placeholder="ДМА-001" required />
                </div>

                <div>
                  <.input field={@form[:name]} type="text" label="Наименование" placeholder="Лаптоп Dell Latitude" required />
                </div>

                <div>
                  <.input
                    field={@form[:category]}
                    type="select"
                    label="Категория"
                    options={[
                      {"Компютърна техника", "computer"},
                      {"Офис оборудване", "office"},
                      {"Транспортни средства", "vehicle"},
                      {"Сгради и помещения", "building"},
                      {"Машини и оборудване", "machinery"},
                      {"Мебели", "furniture"},
                      {"Други", "other"}
                    ]}
                    prompt="Избери категория"
                    required
                  />
                </div>

                <div>
                  <.input field={@form[:inventory_number]} type="text" label="Инвентарен номер" placeholder="INV-2025-001" />
                </div>

                <div>
                  <.input field={@form[:serial_number]} type="text" label="Сериен номер" />
                </div>

                <div>
                  <.input field={@form[:location]} type="text" label="Местонахождение" placeholder="Офис София, ет. 3" />
                </div>

                <div>
                  <.input field={@form[:responsible_person]} type="text" label="МОЛ" placeholder="Иван Иванов" />
                </div>
              </div>
            </div>
          </div>

          <!-- Right Column -->
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-semibold text-zinc-900 mb-3">Финансова информация</h3>

              <div class="space-y-4">
                <div>
                  <.input
                    field={@form[:tax_category]}
                    type="select"
                    label="Данъчна категория ЗКПО"
                    options={tax_category_options()}
                    prompt="Избери категория"
                    phx-change="tax_category_changed"
                    phx-target={@myself}
                  />
                  <%= if @current_tax_rate do %>
                    <p class="mt-1 text-sm text-zinc-500">
                      Автоматична норма: <%= format_percent(@current_tax_rate) %>
                    </p>
                  <% end %>
                </div>

                <div>
                  <.input
                    field={@form[:tax_depreciation_rate]}
                    type="number"
                    label="Данъчна норма (%)"
                    step="0.01"
                    min="0"
                    max="100"
                  />
                  <p class="mt-1 text-xs text-zinc-500">Според ЗКПО</p>
                </div>

                <div>
                  <.input
                    field={@form[:accounting_depreciation_rate]}
                    type="number"
                    label="Счетоводна норма (%)"
                    step="0.01"
                    min="0"
                    max="100"
                  />
                  <p class="mt-1 text-xs text-zinc-500">За финансови отчети</p>
                </div>

                <div>
                  <.input
                    field={@form[:acquisition_date]}
                    type="date"
                    label="Дата на придобиване"
                    required
                  />
                </div>

                <div>
                  <.input
                    field={@form[:startup_date]}
                    type="date"
                    label="Дата на въвеждане в експлоатация"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:purchase_order_date]}
                    type="date"
                    label="Дата на поръчка"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:acquisition_cost]}
                    type="number"
                    label="Стойност на придобиване (лв.)"
                    step="0.01"
                    min="0"
                    required
                  />
                </div>

                <div>
                  <.input
                    field={@form[:salvage_value]}
                    type="number"
                    label="Ликвидационна стойност (лв.)"
                    step="0.01"
                    min="0"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:useful_life_months]}
                    type="number"
                    label="Полезен живот (месеци)"
                    min="1"
                    required
                  />
                </div>

                <div>
                  <.input
                    field={@form[:depreciation_method]}
                    type="select"
                    label="Метод на амортизация"
                    options={[
                      {"Линеен", "straight_line"},
                      {"Намаляващ остатък", "declining_balance"},
                      {"По единици продукция", "units_of_production"}
                    ]}
                    prompt="Избери метод"
                    required
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Full width sections -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Счетоводни сметки</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <.input
                field={@form[:supplier_id]}
                type="select"
                label="Доставчик"
                options={Enum.map(@suppliers, &{&1.name, &1.id})}
                prompt="Избери доставчик"
              />
            </div>

            <div>
              <.input
                field={@form[:accounting_account_id]}
                type="select"
                label="Сметка ДМА (напр. 203)"
                options={Enum.map(@accounts, &{"#{&1.code} - #{&1.name}", &1.id})}
                prompt="Избери сметка"
              />
            </div>

            <div>
              <.input
                field={@form[:expense_account_id]}
                type="select"
                label="Сметка разходи (напр. 603)"
                options={Enum.map(@accounts, &{"#{&1.code} - #{&1.name}", &1.id})}
                prompt="Избери сметка"
              />
            </div>

            <div>
              <.input
                field={@form[:accumulated_depreciation_account_id]}
                type="select"
                label="Сметка амортизация (напр. 2413)"
                options={Enum.map(@accounts, &{"#{&1.code} - #{&1.name}", &1.id})}
                prompt="Избери сметка"
              />
            </div>
          </div>
        </div>

        <.input field={@form[:description]} type="textarea" label="Описание" rows={3} />

        <!-- Actions -->
        <div class="flex items-center justify-end gap-3 border-t border-zinc-200 pt-4">
          <.link patch={@patch} class="rounded-lg px-4 py-2 text-sm font-semibold text-zinc-900 hover:bg-zinc-100">
            Откажи
          </.link>
          <button
            type="submit"
            phx-disable-with="Записване..."
            class="inline-flex justify-center rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800"
          >
            Запази
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{asset: asset} = assigns, socket) do
    changeset = FixedAssets.change_asset(asset)
    suppliers = Contacts.list_contacts(assigns.tenant_id)
    accounts = Accounting.list_accounts(assigns.tenant_id)

    # Get current tax category info from asset data
    tax_category = asset.tax_category
    {current_category, current_rate} = get_tax_category_info(tax_category)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:suppliers, suppliers)
     |> assign(:accounts, accounts)
     |> assign(:current_tax_category, current_category)
     |> assign(:current_tax_rate, current_rate)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"asset" => asset_params}, socket) do
    changeset =
      socket.assigns.asset
      |> FixedAssets.change_asset(asset_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("tax_category_changed", %{"asset" => %{"tax_category" => category}}, socket) do
    {_name, rate} = get_tax_category_info(category)

    # Update the form with the new tax rate
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:tax_depreciation_rate, rate)

    {:noreply,
     socket
     |> assign(:current_tax_category, category)
     |> assign(:current_tax_rate, rate)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"asset" => asset_params}, socket) do
    save_asset(socket, socket.assigns.action, asset_params)
  end

  defp save_asset(socket, :edit, asset_params) do
    case FixedAssets.update_asset(socket.assigns.asset, asset_params) do
      {:ok, asset} ->
        notify_parent({:saved, asset})

        {:noreply,
         socket
         |> put_flash(:info, "Активът е актуализиран успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_asset(socket, :new, asset_params) do
    asset_params_with_tenant = Map.put(asset_params, "tenant_id", socket.assigns.tenant_id)

    case FixedAssets.create_asset(asset_params_with_tenant) do
      {:ok, asset} ->
        notify_parent({:saved, asset})

        {:noreply,
         socket
         |> put_flash(:info, "Активът е създаден успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp get_tax_category_info(nil), do: {nil, nil}
  defp get_tax_category_info(""), do: {nil, nil}

  defp get_tax_category_info(category) do
    case Asset.tax_category_info(category) do
      %{name: name, rate: rate} -> {name, rate}
      _ -> {nil, nil}
    end
  end

  defp tax_category_options do
    Asset.tax_categories()
    |> Enum.map(fn {key, info} ->
      rate_text = if info.rate, do: " (#{format_percent(info.rate)})", else: ""
      {"#{key} - #{info.name}#{rate_text}", key}
    end)
  end

  defp format_percent(nil), do: "-"

  defp format_percent(rate) when is_number(rate) do
    "#{Float.round(rate * 100, 2)}%"
  end

  defp format_percent(%Decimal{} = rate) do
    rate
    |> Decimal.mult(100)
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> then(&"#{&1}%")
  end
end
