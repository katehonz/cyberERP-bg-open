defmodule CyberWeb.ContactLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Contacts
  alias CyberCore.Accounting
  alias CyberCore.Sales.PriceLists
  alias CyberCore.Integrations.ViesValidator
  alias CyberCore.Integrations.MistralAddressParser

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-zinc-900"><%= @title %></h2>
      </div>

      <.form
        for={@form}
        id="contact-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <!-- Basic Information -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Основна информация</h3>

          <div class="space-y-4">
            <div>
              <.input
                field={@form[:is_company]}
                type="checkbox"
                label="Фирма (юридическо лице)"
              />
            </div>

            <div>
              <.input
                field={@form[:name]}
                type="text"
                label="Име"
                placeholder="Име на лицето или фирмата"
                required
              />
            </div>

            <%= if @form[:is_company].value do %>
              <div>
                <.input
                  field={@form[:company]}
                  type="text"
                  label="Фирма"
                  placeholder="Наименование на фирмата"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-zinc-700 mb-1">
                  ДДС номер
                </label>
                <div class="flex gap-2">
                  <.input
                    field={@form[:vat_number]}
                    type="text"
                    placeholder="BG123456789"
                    class="flex-1"
                  />
                  <button
                    type="button"
                    phx-click="validate_vies"
                    phx-target={@myself}
                    class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 disabled:opacity-50"
                    disabled={is_nil(@form[:vat_number].value) || @form[:vat_number].value == ""}
                  >
                    <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418" />
                    </svg>
                    VIES
                  </button>
                </div>
                <%= if @vies_status do %>
                  <p class={"mt-1 text-sm #{if @vies_status == :valid, do: "text-green-600", else: "text-red-600"}"}>
                    <%= if @vies_status == :valid do %>
                      ✓ ДДС номер валидиран успешно
                    <% else %>
                      ✗ <%= @vies_error || "Невалиден ДДС номер" %>
                    <% end %>
                  </p>
                <% end %>
              </div>

              <div>
                <.input
                  field={@form[:registration_number]}
                  type="text"
                  label="ЕИК/Булстат"
                  placeholder="123456789"
                />
              </div>
            <% end %>
          </div>
        </div>

        <!-- Contact Details -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Данни за контакт</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="email@example.com"
              />
            </div>

            <div>
              <.input
                field={@form[:phone]}
                type="text"
                label="Телефон"
                placeholder="+359 888 123 456"
              />
            </div>
          </div>
        </div>

        <!-- Address -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Адрес</h3>

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-zinc-700 mb-1">
                Адрес
              </label>
              <div class="flex gap-2">
                <.input
                  field={@form[:address]}
                  type="text"
                  placeholder="ул. Примерна №1"
                  class="flex-1"
                />
                <button
                  type="button"
                  phx-click="parse_address"
                  phx-target={@myself}
                  class="inline-flex items-center gap-2 rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-purple-700 disabled:opacity-50"
                  disabled={is_nil(@form[:address].value) || @form[:address].value == ""}
                >
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z" />
                  </svg>
                  AI Parse
                </button>
              </div>
            </div>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div>
                <.input
                  field={@form[:city]}
                  type="text"
                  label="Град"
                  placeholder="София"
                />
              </div>

              <div>
                <.input
                  field={@form[:postal_code]}
                  type="text"
                  label="Пощенски код"
                  placeholder="1000"
                />
              </div>

              <div>
                <.input
                  field={@form[:country]}
                  type="text"
                  label="Държава"
                  placeholder="България"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Banking Information -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Банкови данни</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <.input
                field={@form[:bank_name]}
                type="text"
                label="Банка"
                placeholder="Примерна банка"
              />
            </div>

            <div>
              <.input
                field={@form[:bank_account]}
                type="text"
                label="IBAN"
                placeholder="BG80BNBG96611020345678"
              />
            </div>

            <div>
              <.input
                field={@form[:bank_bic]}
                type="text"
                label="BIC/SWIFT"
                placeholder="BNBGBGSD"
              />
            </div>
          </div>
        </div>

        <!-- Payment Terms -->
        <div>
          <h3 class="text-sm font-semibold text-zinc-900 mb-3">Условия за плащане</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <.input
                field={@form[:payment_terms_days]}
                type="number"
                label="Срок на плащане (дни)"
                placeholder="30"
                min="0"
              />
            </div>

            <div>
              <.input
                field={@form[:credit_limit]}
                type="number"
                label="Кредитен лимит"
                step="0.01"
                min="0"
                placeholder="10000.00"
              />
            </div>

            <div class="sm:col-span-2">
              <.input
                field={@form[:price_list_id]}
                type="select"
                label="Ценова листа"
                prompt="-- Изберете ценова листа --"
                options={Enum.map(@price_lists, &{&1.name, &1.id})}
              />
            </div>
          </div>
        </div>

        <!-- Notes -->
        <div>
          <.input
            field={@form[:notes]}
            type="textarea"
            label="Бележки"
            rows={3}
            placeholder="Допълнителна информация..."
          />
        </div>

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
  def update(%{contact: contact} = assigns, socket) do
    changeset = Contacts.change_contact(contact)
    price_lists = PriceLists.list_price_lists(assigns.tenant_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:vies_status, nil)
     |> assign(:vies_error, nil)
     |> assign(:price_lists, price_lists)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    changeset =
      socket.assigns.contact
      |> Contacts.change_contact(contact_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"contact" => contact_params}, socket) do
    save_contact(socket, socket.assigns.action, contact_params)
  end

  @impl true
  def handle_event("validate_vies", _params, socket) do
    vat_number = Phoenix.HTML.Form.input_value(socket.assigns.form, :vat_number)

    if vat_number && vat_number != "" do
      case ViesValidator.validate_vat(vat_number) do
        {:ok, %{valid: true, name: name, address: address, country_code: country_code}} ->
          # Auto-fill form from VIES data
          current_name = Phoenix.HTML.Form.input_value(socket.assigns.form, :name)
          current_address = Phoenix.HTML.Form.input_value(socket.assigns.form, :address)

          updated_params = %{
            "name" => name || current_name,
            "company" => name,
            "address" => address || current_address,
            "country" => country_name_from_code(country_code)
          }

          # Extract Bulgarian EIK if applicable
          updated_params =
            case ViesValidator.extract_bulgarian_eik(vat_number) do
              {:ok, eik} -> Map.put(updated_params, "registration_number", eik)
              _ -> updated_params
            end

          changeset =
            socket.assigns.contact
            |> Contacts.change_contact(updated_params)
            |> Map.put(:action, :validate)

          {:noreply,
           socket
           |> assign(:vies_status, :valid)
           |> assign(:vies_error, nil)
           |> assign_form(changeset)
           |> put_flash(:info, "ДДС номер валидиран успешно: #{name}")}

        {:ok, %{valid: false}} ->
          {:noreply,
           socket
           |> assign(:vies_status, :invalid)
           |> assign(:vies_error, "ДДС номерът не е валиден в VIES регистъра")
           |> put_flash(:error, "ДДС номерът не е валиден")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:vies_status, :error)
           |> assign(:vies_error, reason)
           |> put_flash(:error, "Грешка при валидация: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Моля въведете ДДС номер")}
    end
  end

  @impl true
  def handle_event("parse_address", _params, socket) do
    address = Phoenix.HTML.Form.input_value(socket.assigns.form, :address)

    if address && address != "" do
      case MistralAddressParser.parse_address(address, tenant_id: socket.assigns.tenant_id) do
        {:ok, parsed} ->
          current_city = Phoenix.HTML.Form.input_value(socket.assigns.form, :city)
          current_postal_code = Phoenix.HTML.Form.input_value(socket.assigns.form, :postal_code)
          current_country = Phoenix.HTML.Form.input_value(socket.assigns.form, :country)

          updated_params = %{
            "street_name" => parsed.street_name,
            "building_number" => parsed.building_number,
            "city" => parsed.city || current_city,
            "postal_code" => parsed.postal_code || current_postal_code,
            "country" => parsed.country || current_country,
            "region" => parsed.region,
            "additional_address_detail" => parsed.additional_address_detail
          }

          changeset =
            socket.assigns.contact
            |> Contacts.change_contact(updated_params)
            |> Map.put(:action, :validate)

          {:noreply,
           socket
           |> assign_form(changeset)
           |> put_flash(:info, "Адресът е парсиран успешно с AI")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Грешка при парсване: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Моля въведете адрес")}
    end
  end

  defp save_contact(socket, :edit, contact_params) do
    case Contacts.update_contact(socket.assigns.contact, contact_params) do
      {:ok, contact} ->
        notify_parent({:saved, contact})

        {:noreply,
         socket
         |> put_flash(:info, "Контактът е актуализиран успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_contact(socket, :new, contact_params) do
    contact_params_with_tenant = Map.put(contact_params, "tenant_id", socket.assigns.tenant_id)

    case Contacts.create_contact(contact_params_with_tenant) do
      {:ok, contact} ->
        notify_parent({:saved, contact})

        {:noreply,
         socket
         |> put_flash(:info, "Контактът е създаден успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  # Convert country code to country name
  defp country_name_from_code("BG"), do: "България"
  defp country_name_from_code("DE"), do: "Германия"
  defp country_name_from_code("FR"), do: "Франция"
  defp country_name_from_code("IT"), do: "Италия"
  defp country_name_from_code("ES"), do: "Испания"
  defp country_name_from_code("GB"), do: "Великобритания"
  defp country_name_from_code("RO"), do: "Румъния"
  defp country_name_from_code("GR"), do: "Гърция"
  defp country_name_from_code("PL"), do: "Полша"
  defp country_name_from_code("NL"), do: "Холандия"
  defp country_name_from_code("BE"), do: "Белгия"
  defp country_name_from_code("AT"), do: "Австрия"
  defp country_name_from_code("CZ"), do: "Чехия"
  defp country_name_from_code("HU"), do: "Унгария"
  defp country_name_from_code("PT"), do: "Португалия"
  defp country_name_from_code("SE"), do: "Швеция"
  defp country_name_from_code("DK"), do: "Дания"
  defp country_name_from_code("FI"), do: "Финландия"
  defp country_name_from_code(code), do: code
end
