defmodule CyberWeb.SettingsLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Settings
  alias CyberCore.Accounts
  alias CyberCore.Currencies
  alias CyberCore.Accounting

  @impl true
  def mount(_params, _session, socket) do
    # TODO: Get from session
    tenant_id = 1

    {:ok, settings} = Settings.get_or_create_company_settings(tenant_id)
    {:ok, accounting_settings} = Settings.get_or_create_accounting_settings(tenant_id)
    tenant = Accounts.get_tenant!(tenant_id)
    currencies = Currencies.list_currencies(%{is_active: true})
    accounts = Accounting.list_accounts(tenant_id)

    # Зареждане на integration settings
    azure_setting =
      case Settings.get_integration_setting(tenant_id, "azure_form_recognizer") do
        {:ok, setting} -> setting
        {:error, :not_found} -> nil
      end

    s3_setting =
      case Settings.get_integration_setting(tenant_id, "s3_storage") do
        {:ok, setting} -> setting
        {:error, :not_found} -> nil
      end

    mistral_setting =
      case Settings.get_integration_setting(tenant_id, "mistral_ai") do
        {:ok, setting} -> setting
        {:error, :not_found} -> nil
      end

    smtp_setting =
      case Settings.get_integration_setting(tenant_id, "smtp") do
        {:ok, setting} -> setting
        {:error, :not_found} -> nil
      end

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:settings, settings)
      |> assign(:accounting_settings, accounting_settings)
      |> assign(:tenant, tenant)
      |> assign(:currencies, currencies)
      |> assign(:accounts, accounts)
      |> assign(:page_title, "Настройки на фирмата")
      |> assign(:can_change_currency, can_change_currency?(tenant))
      |> assign(:azure_setting, azure_setting)
      |> assign(:s3_setting, s3_setting)
      |> assign(:mistral_setting, mistral_setting)
      |> assign(:smtp_setting, smtp_setting)
      |> assign(:smtp_testing, false)
      |> assign(:active_tab, "general")
      |> assign(:year_to_prepare, Date.utc_today().year)

    {:ok, socket}
  end

  @impl true
  def handle_event("prepare_year", %{"year" => year_str}, socket) do
    year = String.to_integer(year_str)
    tenant_id = socket.assigns.tenant_id

    case Accounting.FixedAssets.prepare_year_beginning_values(tenant_id, year) do
      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(:info, "Успешно подготвени #{count} активи за #{year} г.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Грешка при подготовка на годината: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def handle_event("select_prepare_year", %{"year" => year}, socket) do
    {:noreply, assign(socket, :year_to_prepare, String.to_integer(year))}
  end

  @impl true
  def handle_event("save_accounting_settings", %{"accounting_settings" => accounting_settings_params}, socket) do
    case Settings.update_accounting_settings(socket.assigns.accounting_settings, accounting_settings_params) do
      {:ok, accounting_settings} ->
        socket =
          socket
          |> put_flash(:info, "Счетоводните настройки са записани успешно")
          |> assign(:accounting_settings, accounting_settings)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Грешка при запазване")}
    end
  end

  @impl true
  def handle_event("save", %{"settings" => settings_params}, socket) do
    case Settings.update_company_settings(socket.assigns.settings, settings_params) do
      {:ok, settings} ->
        socket =
          socket
          |> put_flash(:info, "Настройките са записани успешно")
          |> assign(:settings, settings)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Грешка при запазване")}
    end
  end

  @impl true
  def handle_event("change_currency", %{"currency_code" => currency_code}, socket) do
    attrs = %{base_currency_code: currency_code}

    case Accounts.change_base_currency(socket.assigns.tenant, attrs) do
      {:ok, tenant} ->
        socket =
          socket
          |> put_flash(:info, "Основната валута е променена успешно на #{currency_code}")
          |> assign(:tenant, tenant)
          |> assign(:can_change_currency, can_change_currency?(tenant))

        {:noreply, socket}

      {:error, changeset} ->
        errors = changeset.errors |> Enum.map(fn {_, {msg, _}} -> msg end) |> Enum.join(", ")

        {:noreply,
         put_flash(
           socket,
           :error,
           "Грешка при промяна на валутата: #{errors}"
         )}
    end
  end

  @impl true
  def handle_event("save_azure_settings", %{"azure" => azure_params}, socket) do
    endpoint = String.trim(azure_params["endpoint"] || "")
    api_key = String.trim(azure_params["api_key"] || "")

    if endpoint == "" or api_key == "" do
      {:noreply,
       put_flash(socket, :error, "Моля попълнете всички полета за Azure Form Recognizer")}
    else
      case Settings.upsert_azure_form_recognizer(socket.assigns.tenant_id, endpoint, api_key) do
        {:ok, setting} ->
          socket =
            socket
            |> put_flash(:info, "Azure Form Recognizer настройките са записани успешно")
            |> assign(:azure_setting, setting)

          {:noreply, socket}

        {:error, changeset} ->
          errors = changeset.errors |> Enum.map(fn {_, {msg, _}} -> msg end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, "Грешка при запазване: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("save_s3_settings", %{"s3" => s3_params}, socket) do
    access_key = String.trim(s3_params["access_key"] || "")
    secret_key = String.trim(s3_params["secret_key"] || "")
    host = String.trim(s3_params["host"] || "")
    bucket = String.trim(s3_params["bucket"] || "")

    if access_key == "" or secret_key == "" or host == "" or bucket == "" do
      {:noreply, put_flash(socket, :error, "Моля попълнете всички полета за S3 Storage")}
    else
      case Settings.upsert_s3_storage(
             socket.assigns.tenant_id,
             access_key,
             secret_key,
             host,
             bucket
           ) do
        {:ok, setting} ->
          socket =
            socket
            |> put_flash(:info, "S3 Storage настройките са записани успешно")
            |> assign(:s3_setting, setting)

          {:noreply, socket}

        {:error, changeset} ->
          errors = changeset.errors |> Enum.map(fn {_, {msg, _}} -> msg end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, "Грешка при запазване: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("save_mistral_settings", %{"mistral" => mistral_params}, socket) do
    api_key = String.trim(mistral_params["api_key"] || "")

    if api_key == "" do
      {:noreply, put_flash(socket, :error, "Моля попълнете API Key за Mistral AI")}
    else
      case Settings.upsert_mistral_ai(socket.assigns.tenant_id, api_key) do
        {:ok, setting} ->
          socket =
            socket
            |> put_flash(:info, "Mistral AI настройките са записани успешно")
            |> assign(:mistral_setting, setting)

          {:noreply, socket}

        {:error, changeset} ->
          errors = changeset.errors |> Enum.map(fn {_, {msg, _}} -> msg end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, "Грешка при запазване: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("save_smtp_settings", %{"smtp" => smtp_params}, socket) do
    host = String.trim(smtp_params["host"] || "")
    port = String.trim(smtp_params["port"] || "587")
    username = String.trim(smtp_params["username"] || "")
    password = String.trim(smtp_params["password"] || "")
    from_email = String.trim(smtp_params["from_email"] || "")
    from_name = String.trim(smtp_params["from_name"] || "Cyber ERP")
    ssl = smtp_params["ssl"] == "true"
    tls = smtp_params["tls"] || "if_available"

    if host == "" or username == "" or password == "" or from_email == "" do
      {:noreply, put_flash(socket, :error, "Моля попълнете всички задължителни полета за SMTP")}
    else
      opts = [from_name: from_name, ssl: ssl, tls: tls]

      case Settings.upsert_smtp(
             socket.assigns.tenant_id,
             host,
             String.to_integer(port),
             username,
             password,
             from_email,
             opts
           ) do
        {:ok, setting} ->
          socket =
            socket
            |> put_flash(:info, "SMTP настройките са записани успешно")
            |> assign(:smtp_setting, setting)

          {:noreply, socket}

        {:error, changeset} ->
          errors = changeset.errors |> Enum.map(fn {_, {msg, _}} -> msg end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, "Грешка при запазване: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("test_smtp", _params, socket) do
    socket = assign(socket, :smtp_testing, true)

    case CyberCore.Email.DynamicMailer.test_connection(socket.assigns.tenant_id) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Тестовият email е изпратен успешно! Проверете вашата поща.")
          |> assign(:smtp_testing, false)

        {:noreply, socket}

      {:error, :smtp_not_configured} ->
        {:noreply,
         socket
         |> put_flash(:error, "SMTP не е конфигуриран. Моля попълнете и запазете настройките първо.")
         |> assign(:smtp_testing, false)}

      {:error, :smtp_disabled} ->
        {:noreply,
         socket
         |> put_flash(:error, "SMTP е деактивиран.")
         |> assign(:smtp_testing, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при изпращане на тестов email: #{inspect(reason)}")
         |> assign(:smtp_testing, false)}
    end
  end

  # Проверява дали може да се променя валутата
  defp can_change_currency?(tenant) do
    cond do
      tenant.in_eurozone ->
        false

      tenant.eurozone_entry_date &&
          Date.compare(Date.utc_today(), tenant.eurozone_entry_date) != :lt ->
        false

      true ->
        true
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Настройки на фирмата</h1>
          <p class="mt-2 text-sm text-gray-700">
            Основна информация и интеграции за вашата фирма
          </p>
        </div>
      </div>

      <!-- Линк към управление на фирми -->
      <div class="mt-6">
        <div class="rounded-lg bg-blue-50 border border-blue-200 p-4">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-medium text-blue-900">Управление на фирми</h3>
              <p class="mt-1 text-sm text-blue-700">
                Добавете нови фирми, редактирайте съществуващи или превключете между тях
              </p>
            </div>
            <.link
              href={~p"/tenants"}
              class="inline-flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
            >
              Управление на фирми →
            </.link>
          </div>
        </div>
      </div>

      <!-- Tabs Navigation -->
      <div class="mt-8">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="general"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "general",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              📋 Основни настройки
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="accounting"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "accounting",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              📒 Счетоводство
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="integrations"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "integrations",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              ☁️ AI и Cloud
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="smtp"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "smtp",
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              ✉️ Email (SMTP)
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="mt-8">
        <%= if @active_tab == "general" do %>
          <!-- GENERAL TAB -->
          <form phx-submit="save" class="space-y-6">
            <!-- Основна информация -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Основна информация</h3>

              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <label class="block text-sm font-medium text-gray-700">Наименование *</label>
                  <input
                    type="text"
                    name="settings[company_name]"
                    value={@settings.company_name}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    required
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">ДДС номер *</label>
                  <input
                    type="text"
                    name="settings[vat_number]"
                    value={@settings.vat_number}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    placeholder="BG123456789"
                    required
                  />
                  <p class="mt-1 text-xs text-gray-500">Формат: BGxxxxxxxxx</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">ЕИК</label>
                  <input
                    type="text"
                    name="settings[eik]"
                    value={@settings.eik}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Адрес</label>
                  <input
                    type="text"
                    name="settings[address]"
                    value={@settings.address}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Град</label>
                  <input
                    type="text"
                    name="settings[city]"
                    value={@settings.city}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Телефон</label>
                  <input
                    type="text"
                    name="settings[phone]"
                    value={@settings.phone}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Имейл</label>
                  <input
                    type="email"
                    name="settings[email]"
                    value={@settings.email}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>
              </div>
            </div>
          </div>
          <!-- Банкова информация -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Банкова информация</h3>

              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <label class="block text-sm font-medium text-gray-700">Име на банка</label>
                  <input
                    type="text"
                    name="settings[bank_name]"
                    value={@settings.bank_name}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">BIC</label>
                  <input
                    type="text"
                    name="settings[bank_bic]"
                    value={@settings.bank_bic}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">IBAN</label>
                  <input
                    type="text"
                    name="settings[bank_iban]"
                    value={@settings.bank_iban}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Номерация на документи -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-2">Номерация на документи</h3>
              <p class="text-sm text-gray-500 mb-4">
                Автоматична номерация във формат 10 цифри с водеща нула (например: 0000000001)
              </p>

              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label class="block text-sm font-medium text-gray-700">
                    Следващ номер за фактури за продажба
                  </label>
                  <input
                    type="number"
                    name="settings[sales_invoice_next_number]"
                    value={@settings.sales_invoice_next_number || 1}
                    min="1"
                    max="9999999999"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Текущ формат: <%= CyberCore.Settings.DocumentNumbering.generate_number(@settings.sales_invoice_next_number || 1) %>
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">
                    Следващ номер за протоколи ВОП
                  </label>
                  <input
                    type="number"
                    name="settings[vop_protocol_next_number]"
                    value={@settings.vop_protocol_next_number || 1}
                    min="1"
                    max="9999999999"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Текущ формат: <%= CyberCore.Settings.DocumentNumbering.generate_number(@settings.vop_protocol_next_number || 1) %>
                  </p>
                </div>
              </div>

              <div class="mt-4 bg-blue-50 border border-blue-200 rounded-md p-3">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Информация:</strong> Номерацията е автоматична при създаване на нови документи.
                      Фактурите, дебитни и кредитни известия използват стандартната номерация.
                      Протоколите ВОП (кодове 09, 29, 50, 91-95) използват отделна номерация.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

            <!-- Бутон за запазване -->
            <div class="flex justify-end">
              <button
                type="submit"
                class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
              >
                Запази настройките
              </button>
            </div>
          </form>

          <!-- Валутни настройки -->
          <div class="bg-white shadow sm:rounded-lg mt-8">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Основна валута</h3>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label class="block text-sm font-medium text-gray-700">Текуща основна валута</label>
                <div class="mt-1 block w-full rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-sm">
                  <span class="font-mono font-semibold text-lg"><%= @tenant.base_currency_code %></span>
                </div>
                <%= if @tenant.base_currency_changed_at do %>
                  <p class="mt-1 text-xs text-gray-500">
                    Променена на: <%= Calendar.strftime(@tenant.base_currency_changed_at, "%d.%m.%Y %H:%M") %>
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Смяна на основната валута
                  <%= if not @can_change_currency do %>
                    <span class="text-red-600">(Заключена)</span>
                  <% end %>
                </label>
                <select
                  phx-change="change_currency"
                  name="currency_code"
                  disabled={not @can_change_currency}
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <%= for currency <- @currencies do %>
                    <option value={currency.code} selected={currency.code == @tenant.base_currency_code}>
                      <%= currency.code %> - <%= currency.name %>
                    </option>
                  <% end %>
                </select>
                <%= if not @can_change_currency do %>
                  <%= if @tenant.in_eurozone do %>
                    <p class="mt-1 text-xs text-red-600">
                      ⚠️ Вашата организация е в еврозоната. Основната валута е EUR и не може да се променя.
                    </p>
                  <% else %>
                    <p class="mt-1 text-xs text-red-600">
                      ⚠️ Основната валута е заключена след <%= Date.to_iso8601(@tenant.eurozone_entry_date) %>
                    </p>
                  <% end %>
                <% else %>
                  <p class="mt-1 text-xs text-gray-500">
                    Изберете валута от падащото меню за смяна.
                  </p>
                <% end %>
              </div>
            </div>
            <!-- Информация за еврозоната -->
            <%= if @tenant.in_eurozone do %>
              <div class="mt-4 rounded-md bg-blue-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg
                      class="h-5 w-5 text-blue-400"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                  <div class="ml-3 flex-1 md:flex md:justify-between">
                    <p class="text-sm text-blue-700">
                      Организацията е влязла в еврозоната на <%= Date.to_iso8601(@tenant.eurozone_entry_date) %>. Валутните курсове се актуализират от ЕЦБ (Европейска централна банка).
                    </p>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="mt-4 rounded-md bg-yellow-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg
                      class="h-5 w-5 text-yellow-400"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                  <div class="ml-3 flex-1 md:flex md:justify-between">
                    <p class="text-sm text-yellow-700">
                      <strong>Важно:</strong>
                      От 2026 година, когато България влезе в еврозоната, основната валута автоматично ще се смени на EUR и няма да може да се променя. Валутните курсове ще се взимат от ЕЦБ.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
            </div>
          </div>
        <% end %>

        <%= if @active_tab == "accounting" do %>
          <!-- ACCOUNTING TAB -->
          <form phx-submit="save_accounting_settings" class="space-y-6">
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Счетоводни настройки по подразбиране</h3>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Доставчици</label>
                        <select name="accounting_settings[suppliers_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.suppliers_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Клиенти</label>
                        <select name="accounting_settings[customers_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.customers_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Каса</label>
                        <select name="accounting_settings[cash_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.cash_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка ДДС продажби</label>
                        <select name="accounting_settings[vat_sales_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.vat_sales_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка ДДС Покупки</label>
                        <select name="accounting_settings[vat_purchases_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.vat_purchases_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Дефолт Сметка за приходи</label>
                        <select name="accounting_settings[default_income_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.default_income_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Стоки</label>
                        <select name="accounting_settings[inventory_goods_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.inventory_goods_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Материали</label>
                        <select name="accounting_settings[inventory_materials_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.inventory_materials_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Продукция</label>
                        <select name="accounting_settings[inventory_produced_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.inventory_produced_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Себестойност</label>
                        <select name="accounting_settings[cogs_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.cogs_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700">Сметка Незавършено производство</label>
                        <select name="accounting_settings[wip_account_id]" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                            <option value="">Избери сметка</option>
                            <%= for account <- @accounts do %>
                                <option value={account.id} selected={@accounting_settings.wip_account_id == account.id}><%= account.code %> - <%= account.name %></option>
                            <% end %>
                        </select>
                    </div>
                </div>
              </div>
            </div>
            <div class="bg-white shadow sm:rounded-lg mt-8">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Годишни процедури (SAF-T)</h3>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div>
                    <h4 class="text-sm font-medium text-gray-700">Подготовка за нова година</h4>
                    <p class="mt-1 text-sm text-gray-500">
                      Подготвя началните стойности на всички активи за SAF-T отчитане.
                      Изпълнете тази операция на 1 януари.
                    </p>
                  </div>
                  <div class="flex items-center gap-4">
                    <select
                      id="prepare-year"
                      name="year"
                      class="rounded-md border-gray-300 shadow-sm"
                      phx-change="select_prepare_year"
                    >
                      <%= for year <- (@year_to_prepare - 2)..(@year_to_prepare + 1) do %>
                        <option value={year} selected={year == @year_to_prepare}><%= year %></option>
                      <% end %>
                    </select>
                    <button
                      type="button"
                      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700"
                      phx-click="prepare_year"
                      phx-value-year={@year_to_prepare}
                      data-confirm={"Сигурни ли сте, че искате да подготвите активите за #{@year_to_prepare} г.? Тази операция не може да бъде отменена."}
                    >
                      Подготви година <%= @year_to_prepare %>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <button
                type="submit"
                class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
              >
                Запази счетоводните настройки
              </button>
            </div>
          </form>
        <% end %>

        <%= if @active_tab == "integrations" do %>
          <!-- INTEGRATIONS TAB -->
          <!-- AI и Cloud Інтеграции -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-2">AI и Cloud Интеграции</h3>
              <p class="text-sm text-gray-500 mb-6">
                Настройки за автоматично извличане на данни от фактури и архивиране на базата данни
              </p>

              <!-- Azure Form Recognizer -->
              <div class="mb-8">
                <h4 class="text-base font-medium text-gray-900 mb-4 flex items-center">
                  <svg class="h-5 w-5 text-blue-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z"/>
                  </svg>
                  Azure Form Recognizer
                  <%= if @azure_setting && @azure_setting.enabled do %>
                    <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Активна
                    </span>
                  <% end %>
                </h4>

                <form phx-submit="save_azure_settings" class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Azure Endpoint *</label>
                    <input
                      type="text"
                      name="azure[endpoint]"
                      value={@azure_setting && @azure_setting.config["endpoint"]}
                      placeholder="https://your-resource.cognitiveservices.azure.com/"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                      required
                    />
                    <p class="mt-1 text-xs text-gray-500">
                      Endpoint URL от Azure Portal → Keys and Endpoint
                    </p>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">API Key *</label>
                    <input
                      type="password"
                      name="azure[api_key]"
                      value={@azure_setting && @azure_setting.config["api_key"]}
                      placeholder="••••••••••••••••"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                      required
                    />
                    <p class="mt-1 text-xs text-gray-500">
                      API Key от Azure Portal → Keys and Endpoint → Key 1
                    </p>
                  </div>

                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="inline-flex justify-center rounded-md border border-transparent bg-blue-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                    >
                      Запази Azure настройки
                    </button>
                  </div>
                </form>
              </div>

              <!-- S3 Storage for Database Backup -->
              <div class="mb-8 border-t border-gray-200 pt-8">
                <h4 class="text-base font-medium text-gray-900 mb-4 flex items-center">
                  <svg class="h-5 w-5 text-orange-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3c0 1.657-3.134 3-7 3s-7-1.343-7-3z"/>
                    <path d="M3 7v3c0 1.657 3.134 3 7 3s7-1.343 7-3V7c0 1.657-3.134 3-7 3S3 8.657 3 7z"/>
                    <path d="M17 5c0 1.657-3.134 3-7 3S3 6.657 3 5s3.134-3 7-3 7 1.343 7 3z"/>
                  </svg>
                  S3 Storage (за архив на базата данни)
                  <%= if @s3_setting && @s3_setting.enabled do %>
                    <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Активна
                    </span>
                  <% end %>
                </h4>

                <form phx-submit="save_s3_settings" class="space-y-4">
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Access Key ID *</label>
                      <input
                        type="text"
                        name="s3[access_key]"
                        value={@s3_setting && @s3_setting.config["access_key"]}
                        placeholder="access_key_id"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                        required
                      />
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700">Secret Access Key *</label>
                      <input
                        type="password"
                        name="s3[secret_key]"
                        value={@s3_setting && @s3_setting.config["secret_key"]}
                        placeholder="••••••••••••••••"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                        required
                      />
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700">S3 Host *</label>
                      <input
                        type="text"
                        name="s3[host]"
                        value={@s3_setting && @s3_setting.config["host"]}
                        placeholder="fsn1.your-objectstorage.com"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        required
                      />
                      <p class="mt-1 text-xs text-gray-500">
                        Hetzner S3 endpoint (напр: fsn1.your-objectstorage.com)
                      </p>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700">S3 Bucket *</label>
                      <input
                        type="text"
                        name="s3[bucket]"
                        value={@s3_setting && @s3_setting.config["bucket"]}
                        placeholder="my-database-backups"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        required
                      />
                    </div>
                  </div>

                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="inline-flex justify-center rounded-md border border-transparent bg-orange-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:ring-offset-2"
                    >
                      Запази S3 настройки
                    </button>
                  </div>
                </form>

                <div class="mt-4 bg-orange-50 border border-orange-200 rounded-md p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-orange-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-orange-700">
                        <strong>Предназначение:</strong> S3 Storage се използва САМО за автоматично архивиране на базата данни (PostgreSQL dump).
                      </p>
                      <p class="text-sm text-orange-700 mt-2">
                        PDF документи за AI обработка НЕ се съхраняват в S3 - те се обработват директно от браузъра към Azure.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Mistral AI -->
              <div class="mb-8 border-t border-gray-200 pt-8">
                <h4 class="text-base font-medium text-gray-900 mb-4 flex items-center">
                  <svg class="h-5 w-5 text-purple-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                  Mistral AI (Парсиране на адреси)
                  <%= if @mistral_setting && @mistral_setting.enabled do %>
                    <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Активна
                    </span>
                  <% end %>
                </h4>

                <form phx-submit="save_mistral_settings" class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">API Key *</label>
                    <input
                      type="password"
                      name="mistral[api_key]"
                      value={@mistral_setting && @mistral_setting.config["api_key"]}
                      placeholder="••••••••••••••••"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm font-mono"
                      required
                    />
                    <p class="mt-1 text-xs text-gray-500">
                      API Key от Mistral AI Console → API Keys
                    </p>
                  </div>

                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="inline-flex justify-center rounded-md border border-transparent bg-purple-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
                    >
                      Запази Mistral настройки
                    </button>
                  </div>
                </form>

                <div class="mt-4 bg-purple-50 border border-purple-200 rounded-md p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-purple-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-purple-700">
                        <strong>Предназначение:</strong> Mistral AI се използва за автоматично парсиране на адреси в структуриран формат.
                      </p>
                      <p class="text-sm text-purple-700 mt-2">
                        Използва се при добавяне на контрагенти за извличане на улица, номер, град, пощенски код и др.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Информационна секция -->
              <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1 a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Azure Form Recognizer:</strong> Автоматично извличане на данни от PDF фактури чрез AI.
                    </p>
                    <p class="text-sm text-blue-700 mt-2">
                      PDF файловете се обработват директно от браузъра към Azure - не е необходимо S3 storage.
                    </p>
                    <p class="text-sm text-blue-700 mt-2">
                      За повече информация вижте документацията:
                      <a href="/docs/AZURE_FORM_RECOGNIZER_SETUP.md" class="underline">Azure Form Recognizer Setup</a>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @active_tab == "smtp" do %>
          <!-- SMTP TAB -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-2">SMTP настройки за изпращане на email</h3>
              <p class="text-sm text-gray-500 mb-6">
                Конфигурирайте SMTP сървър за изпращане на автоматични имейли (възстановяване на парола, известия и др.)
              </p>

              <form phx-submit="save_smtp_settings" class="space-y-6">
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">SMTP Сървър *</label>
                    <input
                      type="text"
                      name="smtp[host]"
                      value={@smtp_setting && @smtp_setting.config["host"]}
                      placeholder="smtp.gmail.com"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Порт *</label>
                    <input
                      type="number"
                      name="smtp[port]"
                      value={@smtp_setting && @smtp_setting.config["port"] || 587}
                      placeholder="587"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      required
                    />
                    <p class="mt-1 text-xs text-gray-500">Обикновено 587 (TLS) или 465 (SSL)</p>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Потребител *</label>
                    <input
                      type="text"
                      name="smtp[username]"
                      value={@smtp_setting && @smtp_setting.config["username"]}
                      placeholder="user@example.com"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Парола *</label>
                    <input
                      type="password"
                      name="smtp[password]"
                      value={@smtp_setting && @smtp_setting.config["password"]}
                      placeholder="••••••••••••"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm font-mono"
                      required
                    />
                    <p class="mt-1 text-xs text-gray-500">За Gmail използвайте App Password</p>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">От Email *</label>
                    <input
                      type="email"
                      name="smtp[from_email]"
                      value={@smtp_setting && @smtp_setting.config["from_email"]}
                      placeholder="noreply@example.com"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">От Име</label>
                    <input
                      type="text"
                      name="smtp[from_name]"
                      value={@smtp_setting && @smtp_setting.config["from_name"] || "Cyber ERP"}
                      placeholder="Cyber ERP"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">TLS</label>
                    <select
                      name="smtp[tls]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <option value="if_available" selected={!@smtp_setting || @smtp_setting.config["tls"] == "if_available"}>Ако е наличен</option>
                      <option value="always" selected={@smtp_setting && @smtp_setting.config["tls"] == "always"}>Винаги</option>
                      <option value="never" selected={@smtp_setting && @smtp_setting.config["tls"] == "never"}>Никога</option>
                    </select>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">SSL</label>
                    <select
                      name="smtp[ssl]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    >
                      <option value="false" selected={!@smtp_setting || @smtp_setting.config["ssl"] != true}>Изключен</option>
                      <option value="true" selected={@smtp_setting && @smtp_setting.config["ssl"] == true}>Включен</option>
                    </select>
                    <p class="mt-1 text-xs text-gray-500">Включете за порт 465</p>
                  </div>
                </div>

                <div class="flex justify-between items-center pt-4 border-t border-gray-200">
                  <button
                    type="button"
                    phx-click="test_smtp"
                    disabled={@smtp_testing || !@smtp_setting}
                    class="inline-flex items-center rounded-md border border-emerald-300 bg-white px-4 py-2 text-sm font-medium text-emerald-700 shadow-sm hover:bg-emerald-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <%= if @smtp_testing do %>
                      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-emerald-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Изпращане...
                    <% else %>
                      <svg class="-ml-1 mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                      Изпрати тестов email
                    <% end %>
                  </button>

                  <button
                    type="submit"
                    class="inline-flex justify-center rounded-md border border-transparent bg-emerald-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
                  >
                    Запази SMTP настройки
                  </button>
                </div>
              </form>

              <!-- Статус -->
              <div class="mt-6">
                <%= if @smtp_setting && @smtp_setting.enabled do %>
                  <div class="rounded-md bg-green-50 p-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-green-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <p class="text-sm font-medium text-green-800">
                          SMTP е конфигуриран и активен
                        </p>
                        <p class="mt-1 text-sm text-green-700">
                          Сървър: <%= @smtp_setting.config["host"] %>:<%= @smtp_setting.config["port"] %>
                        </p>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="rounded-md bg-yellow-50 p-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <p class="text-sm font-medium text-yellow-800">
                          SMTP не е конфигуриран
                        </p>
                        <p class="mt-1 text-sm text-yellow-700">
                          Попълнете настройките за да активирате изпращане на имейли.
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Помощна информация -->
              <div class="mt-6 bg-gray-50 border border-gray-200 rounded-md p-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Често използвани SMTP сървъри:</h4>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                  <div>
                    <p class="font-medium text-gray-700">Gmail</p>
                    <p class="text-gray-500">smtp.gmail.com:587 (TLS)</p>
                    <p class="text-xs text-gray-400">Нужен е App Password</p>
                  </div>
                  <div>
                    <p class="font-medium text-gray-700">Outlook/Office 365</p>
                    <p class="text-gray-500">smtp.office365.com:587 (TLS)</p>
                  </div>
                  <div>
                    <p class="font-medium text-gray-700">Mailgun</p>
                    <p class="text-gray-500">smtp.mailgun.org:587 (TLS)</p>
                  </div>
                  <div>
                    <p class="font-medium text-gray-700">SendGrid</p>
                    <p class="text-gray-500">smtp.sendgrid.net:587 (TLS)</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
