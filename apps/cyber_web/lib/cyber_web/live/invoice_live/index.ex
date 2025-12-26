defmodule CyberWeb.InvoiceLive.Index do
  use CyberWeb, :live_view

  alias Phoenix.LiveView.JS
  alias CyberCore.Sales
  alias CyberCore.Settings

  @impl true
  def mount(_params, _session, socket) do
    bank_accounts = load_bank_accounts()
    settings = Settings.get_company_settings!(1)

    {:ok,
     socket
     |> assign(:page_title, "Фактури")
     |> assign(:invoices, [])
     |> assign(:invoice, nil)
     |> assign(:form, nil)
     |> assign(:invoice_lines, [])
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)
     |> assign(:bank_accounts, bank_accounts)
     |> assign(:settings, settings)
     |> assign(:selected_contact_id, nil)
     |> assign(:show_contact_search_modal, false)
     |> assign(:show_product_search_modal, false)
     |> assign(:product_search_line_index, nil)
     |> load_invoices()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Фактури")
    |> assign(:invoice, nil)
    |> assign(:form, nil)
    |> assign(:invoice_lines, [])
  end

  defp apply_action(socket, :new, _params) do
    default_currency = CyberCore.Settings.get_default_currency(1)
    settings = socket.assigns.settings

    # Определяме ДДС ставката според регистрация
    default_vat_rate = if settings.is_vat_registered, do: 20, else: 0

    invoice = %Sales.Invoice{
      issue_date: Date.utc_today(),
      due_date: Date.add(Date.utc_today(), 14),
      tax_event_date: Date.utc_today(),
      currency: default_currency,
      status: "draft",
      vat_document_type: "01",
      payment_method: "cash"
    }

    changeset = Sales.change_invoice(invoice)

    # Начален празен ред
    initial_line = %{
      product_id: nil,
      description: "",
      quantity: 1,
      unit_price: 0,
      discount_percent: 0,
      tax_rate: default_vat_rate
    }

    socket
    |> assign(:page_title, "Нова фактура")
    |> assign(:invoice, invoice)
    |> assign(:form, to_form(changeset))
    |> assign(:invoice_lines, [initial_line])
    |> assign(:default_vat_rate, default_vat_rate)
    |> assign(:price_list_id, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    invoice = Sales.get_invoice!(1, id, [:invoice_lines])
    changeset = Sales.change_invoice(invoice)
    settings = socket.assigns.settings

    # Определяме ДДС ставката според регистрация
    default_vat_rate = if settings.is_vat_registered, do: 20, else: 0

    # Конвертираме invoice_lines за показване
    lines =
      Enum.map(invoice.invoice_lines || [], fn line ->
        %{
          description: line.description,
          quantity: line.quantity,
          unit_price: line.unit_price,
          tax_rate: line.tax_rate,
          discount_percent: line.discount_percent || 0,
          product_id: line.product_id
        }
      end)

    socket
    |> assign(:page_title, "Редактиране на фактура")
    |> assign(:invoice, invoice)
    |> assign(:form, to_form(changeset))
    |> assign(:invoice_lines, lines)
    |> assign(:default_vat_rate, default_vat_rate)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    invoice = Sales.get_invoice!(1, id)

    socket
    |> assign(:page_title, "Фактура #{invoice.invoice_no}")
    |> assign(:invoice, invoice)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_invoices()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_invoices()}
  end

  def handle_event("filter_dates", %{"from" => from, "to" => to}, socket) do
    {:noreply,
     socket
     |> assign(:date_from, from)
     |> assign(:date_to, to)
     |> load_invoices()}
  end

  def handle_event("issue_invoice", %{"id" => id}, socket) do
    invoice = Sales.get_invoice!(1, id)

    case Sales.issue_invoice(invoice) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Фактурата беше издадена и регистрирана в ДДС дневник продажби")
         |> load_invoices()}

      {:error, :invoice_not_draft} ->
        {:noreply,
         socket
         |> put_flash(:error, "Може да се издават само чернови фактури")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при издаване: #{inspect(reason)}")}
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    invoice = Sales.get_invoice!(1, id)

    case Sales.mark_invoice_paid(invoice) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Фактурата беше маркирана като платена")
         |> load_invoices()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка: #{inspect(reason)}")}
    end
  end

  def handle_event("revert_to_draft", %{"id" => id}, socket) do
    invoice = Sales.get_invoice!(1, id)

    case Sales.revert_invoice_to_draft(invoice) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Фактурата беше върната към статус 'чернова' и премахната от ДДС дневник"
         )
         |> load_invoices()}

      {:error, :invoice_already_draft} ->
        {:noreply,
         socket
         |> put_flash(:error, "Фактурата вече е чернова")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при връщане: #{inspect(reason)}")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    invoice = Sales.get_invoice!(1, id)
    {:ok, _} = Sales.delete_invoice(invoice)

    {:noreply,
     socket
     |> put_flash(:info, "Фактурата беше изтрита успешно")
     |> load_invoices()}
  end

  def handle_event("open_contact_search", _, socket) do
    {:noreply, assign(socket, :show_contact_search_modal, true)}
  end



  def handle_event("open_product_search", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> assign(:show_product_search_modal, true)
     |> assign(:product_search_line_index, String.to_integer(index))}
  end

  @impl true
  def handle_info({:search_modal_selected, %{item: item, field: :contact_id}}, socket) do
    contact = CyberCore.Contacts.get_contact!(1, item.id)
    price_list_id = contact.price_list_id

    updated_params =
      socket.assigns.form
      |> form_params()
      |> Map.merge(%{
        "contact_id" => contact.id,
        "billing_name" => contact.name,
        "billing_address" => contact.address,
        "billing_vat_number" => contact.vat_number,
        "billing_company_id" => contact.registration_number
      })

    changeset = Sales.change_invoice(socket.assigns.invoice, updated_params)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:price_list_id, price_list_id)
     |> assign(:show_contact_search_modal, false)}
  end

  def handle_info({:search_modal_selected, %{item: item, field: :product_id}}, socket) do
    line_index = socket.assigns.product_search_line_index
    price_list_id = socket.assigns.price_list_id

    unit_price =
      if price_list_id do
        case CyberCore.Sales.PriceLists.get_item_by_product(price_list_id, item.id) do
          nil -> item.price
          price_list_item -> price_list_item.price
        end
      else
        item.price
      end

    updated_lines =
      List.update_at(socket.assigns.invoice_lines, line_index, fn line ->
        line
        |> Map.put(:product_id, item.id)
        |> Map.put(:description, item.name)
        |> Map.put(:unit_price, unit_price)
      end)

    {:noreply,
     socket
     |> assign(:invoice_lines, updated_lines)
     |> assign(:show_product_search_modal, false)}
  end

  def handle_info({:search_modal_cancelled, _}, socket) do
    {:noreply,
     socket
     |> assign(:show_contact_search_modal, false)
     |> assign(:show_product_search_modal, false)}
  end


  def handle_event("select_oss_country", %{"invoice" => %{"oss_country" => country_code}}, socket) do
    vat_rate = Sales.get_oss_vat_rate(country_code)

    updated_lines =
      Enum.map(socket.assigns.invoice_lines, fn line ->
        Map.put(line, :tax_rate, vat_rate)
      end)

    updated_params =
      socket.assigns.form
      |> form_params()
      |> Map.put("oss_country", country_code)

    changeset = Sales.change_invoice(socket.assigns.invoice, updated_params)

    {:noreply,
     socket
     |> assign(:invoice_lines, updated_lines)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate", %{"invoice" => invoice_params, "lines" => lines_params}, socket) do
    lines =
      Enum.map(lines_params, fn {_index, line_map} ->
        %{
          description: Map.get(line_map, "description", ""),
          quantity: Map.get(line_map, "quantity", "1") |> to_decimal(),
          unit_price: Map.get(line_map, "unit_price", "0") |> to_decimal(),
          tax_rate: Map.get(line_map, "tax_rate", "20") |> to_decimal(),
          discount_percent: Map.get(line_map, "discount_percent", "0") |> to_decimal(),
          product_id: Map.get(line_map, "product_id") |> parse_integer()
        }
      end)

    changeset =
      socket.assigns.invoice
      |> Sales.change_invoice(invoice_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:invoice_lines, lines)}
  end

  def handle_event("validate", %{"invoice" => invoice_params}, socket) do
    changeset =
      socket.assigns.invoice
      |> Sales.change_invoice(invoice_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save_or_print", %{"action" => "print", "invoice" => invoice_params, "lines" => lines_params}, socket) do
    # The `lines_params` is a map of index to line map. We just need the values.
    lines = Enum.map(lines_params, fn {_i, l} -> l end)
    all_params = Map.merge(invoice_params, %{"lines" => lines})

    case CyberWeb.Pdf.InvoicePdf.generate(all_params) do
      {:ok, pdf_binary} ->
        encoded_pdf = Base.encode64(pdf_binary)
        # Create a filename based on document type and number
        doc_type_name =
          case all_params["vat_document_type"] do
            "01" -> "invoice"
            "02" -> "credit-note"
            "03" -> "debit-note"
            _ -> "document"
          end

        filename = "#{doc_type_name}-#{all_params["invoice_no"] || "new"}.pdf"

        {:noreply,
         socket
         |> push_event("download-pdf", %{data: encoded_pdf, filename: filename})}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Грешка при генериране на PDF: #{reason}")}
    end
  end

  def handle_event("save_or_print", %{"invoice" => invoice_params, "lines" => lines_params}, socket) do
    # Default action is "save"
    save_invoice(socket, socket.assigns.live_action, invoice_params, lines_params)
  end

  def handle_event("add_line", _params, socket) do
    # Използваме default_vat_rate или 20% ако не е зададена
    default_rate = Map.get(socket.assigns, :default_vat_rate, 20)

    new_line = %{
      product_id: nil,
      description: "",
      quantity: 1,
      unit_price: 0,
      discount_percent: 0,
      tax_rate: default_rate
    }

    {:noreply, assign(socket, :invoice_lines, socket.assigns.invoice_lines ++ [new_line])}
  end

  defp load_invoices(socket) do
    opts = build_filter_opts(socket)
    invoices = Sales.list_invoices(1, opts)

    assign(socket, :invoices, invoices)
  end

  defp build_filter_opts(socket) do
    opts = []

    opts =
      case socket.assigns.filter_status do
        "all" -> opts
        status -> [{:status, status} | opts]
      end

    opts =
      if socket.assigns.search_query != "" do
        [{:search, socket.assigns.search_query} | opts]
      else
        opts
      end

    opts =
      if socket.assigns.date_from && socket.assigns.date_from != "" do
        [{:from, socket.assigns.date_from} | opts]
      else
        opts
      end

    opts =
      if socket.assigns.date_to && socket.assigns.date_to != "" do
        [{:to, socket.assigns.date_to} | opts]
      else
        opts
      end

    opts
  end

  defp save_invoice(socket, :edit, invoice_params, lines_params) do
    case Sales.update_invoice_with_lines(socket.assigns.invoice, invoice_params, lines_params) do
      {:ok, _invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Фактурата беше актуализирана успешно")
         |> push_patch(to: ~p"/invoices")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_invoice(socket, :new, invoice_params, lines_params) do
    # Добавяме tenant_id
    invoice_params = Map.put(invoice_params, "tenant_id", 1)

    # Конвертираме lines от map към list
    lines_list = convert_lines_params(lines_params)

    case Sales.create_invoice_with_lines(invoice_params, lines_list) do
      {:ok, _invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Фактурата беше създадена успешно")
         |> push_patch(to: ~p"/invoices")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при създаване на фактура")
         |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @live_action in [:new, :edit] do %>
      <div
        id="invoice-modal"
        class="relative z-50"
      >
        <div class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
        <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true">
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="w-full max-w-7xl">
              <div
                id="invoice-modal-container"
                phx-window-keydown={JS.patch(~p"/invoices")}
                phx-key="escape"
                phx-hook="PdfDownloader"
                class="relative rounded-2xl bg-white p-6 shadow-lg ring-1 ring-zinc-700/10"
              >
                <div class="absolute top-6 right-5">
                  <button
                    phx-click={JS.patch(~p"/invoices")}
                    type="button"
                    class="flex h-8 w-8 items-center justify-center rounded-lg text-gray-400 hover:text-gray-500"
                  >
                    <span class="sr-only">Close</span>
                    <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <h2 class="text-lg font-medium text-gray-900 mb-4">
                  <%= @page_title %>
                </h2>

      <form phx-change="validate" phx-submit="save_or_print" class="space-y-6">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label for="invoice_no" class="block text-sm font-medium text-gray-700">
              Номер <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="invoice[invoice_no]"
              id="invoice_no"
              value={Phoenix.HTML.Form.input_value(@form, :invoice_no)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
            <%= if @form && @form.errors[:invoice_no] do %>
              <p class="mt-2 text-sm text-red-600">
                <%= translate_error(@form.errors[:invoice_no]) %>
              </p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">
              Клиент <span class="text-red-500">*</span>
            </label>
            <div class="mt-1">
              <div class="flex rounded-md shadow-sm">
                <input
                  type="text"
                  class="w-full rounded-none rounded-l-md border-gray-300 bg-gray-100"
                  value={@form[:billing_name].value}
                  readonly="readonly"
                />
                <button
                  type="button"
                  class="relative -ml-px inline-flex items-center space-x-2 rounded-r-md border border-gray-300 bg-gray-50 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
                  phx-click="open_contact_search"
                >
                  <span>Търси</span>
                </button>
              </div>
            </div>
          </div>

          <div>
            <label for="issue_date" class="block text-sm font-medium text-gray-700">
              Дата <span class="text-red-500">*</span>
            </label>
            <input
              type="date"
              name="invoice[issue_date]"
              id="issue_date"
              value={Phoenix.HTML.Form.input_value(@form, :issue_date)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label for="tax_event_date" class="block text-sm font-medium text-gray-700">
              Дата на данъчното събитие (ДДС дата)
            </label>
            <input
              type="date"
              name="invoice[tax_event_date]"
              id="tax_event_date"
              value={Phoenix.HTML.Form.input_value(@form, :tax_event_date)}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label for="due_date" class="block text-sm font-medium text-gray-700">
              Падеж
            </label>
            <input
              type="date"
              name="invoice[due_date]"
              id="due_date"
              value={Phoenix.HTML.Form.input_value(@form, :due_date)}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label for="payment_method" class="block text-sm font-medium text-gray-700">
              Начин на плащане
            </label>
            <select
              name="invoice[payment_method]"
              id="payment_method"
              phx-change="validate"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <option value="cash" selected={Phoenix.HTML.Form.input_value(@form, :payment_method) == "cash"}>В брой</option>
              <option value="card" selected={Phoenix.HTML.Form.input_value(@form, :payment_method) == "card"}>С карта</option>
              <option value="bank" selected={Phoenix.HTML.Form.input_value(@form, :payment_method) == "bank"}>По банка</option>
            </select>
          </div>

          <%= if Phoenix.HTML.Form.input_value(@form, :payment_method) == "bank" do %>
            <div>
              <label for="bank_account_id" class="block text-sm font-medium text-gray-700">
                Банкова сметка <span class="text-red-500">*</span>
              </label>
              <select
                name="invoice[bank_account_id]"
                id="bank_account_id"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Изберете банкова сметка...</option>
                <%= for account <- @bank_accounts do %>
                  <option value={account.id} selected={Phoenix.HTML.Form.input_value(@form, :bank_account_id) == account.id}>
                    <%= account.bank_name %> - <%= account.iban %> (<%= account.currency %>)
                  </option>
                <% end %>
              </select>
            </div>
          <% end %>
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label for="billing_name" class="block text-sm font-medium text-gray-700">
              Име на клиент <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="invoice[billing_name]"
              id="billing_name"
              value={Phoenix.HTML.Form.input_value(@form, :billing_name)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label for="billing_vat_number" class="block text-sm font-medium text-gray-700">
              ДДС номер
            </label>
            <input
              type="text"
              name="invoice[billing_vat_number]"
              id="billing_vat_number"
              value={Phoenix.HTML.Form.input_value(@form, :billing_vat_number)}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div class="sm:col-span-2">
            <label for="billing_address" class="block text-sm font-medium text-gray-700">
              Адрес
            </label>
            <input
              type="text"
              name="invoice[billing_address]"
              id="billing_address"
              value={Phoenix.HTML.Form.input_value(@form, :billing_address)}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <!-- Редове на фактурата -->
        <div class="border-t pt-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-base font-medium text-gray-900">Артикули</h3>
            <button
              type="button"
              phx-click="add_line"
              class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
            >
              + Добави ред
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Продукт</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Описание</th>
                  <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Кол.</th>
                  <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Ед. цена</th>
                  <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Отстъпка %</th>
                  <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">ДДС %</th>
                  <th class="px-3 py-2"></th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for {line, index} <- Enum.with_index(@invoice_lines) do %>
                  <tr>
                    <td class="px-3 py-2">
                      <input type="hidden" name={"lines[#{index}][product_id]"} value={line.product_id} />
                      <div class="flex rounded-md shadow-sm">
                        <input
                          type="text"
                          id={"product-name-#{index}-#{line.product_id}"}
                          class="w-full rounded-none rounded-l-md border-gray-300 bg-gray-100"
                          value={get_product_name(line.product_id)}
                          readonly
                        />
                        <button
                          type="button"
                          class="relative -ml-px inline-flex items-center space-x-2 rounded-r-md border border-gray-300 bg-gray-50 px-2 py-1 text-sm font-medium text-gray-700 hover:bg-gray-100"
                          phx-click="open_product_search"
                          phx-value-index={index}
                        >
                          <Heroicons.magnifying_glass class="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                    <td class="px-3 py-2">
                      <input
                        type="text"
                        name={"lines[#{index}][description]"}
                        value={line.description}
                        placeholder="Описание..."
                        class="block w-full border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                      />
                    </td>
                    <td class="px-3 py-2">
                      <input
                        type="number"
                        name={"lines[#{index}][quantity]"}
                        value={line.quantity}
                        step="0.01"
                        class="block w-24 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                      />
                    </td>
                    <td class="px-3 py-2">
                      <input
                        type="number"
                        name={"lines[#{index}][unit_price]"}
                        value={line.unit_price}
                        step="0.01"
                        class="block w-28 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                      />
                    </td>
                    <td class="px-3 py-2">
                      <input
                        type="number"
                        name={"lines[#{index}][discount_percent]"}
                        value={line.discount_percent || 0}
                        step="0.01"
                        class="block w-24 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                      />
                    </td>
                    <td class="px-3 py-2">
                      <input
                        type="number"
                        name={"lines[#{index}][tax_rate]"}
                        value={line.tax_rate}
                        step="0.01"
                        phx-change="validate"
                        class="block w-24 text-right border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm"
                      />
                    </td>
                    <td class="px-3 py-2 text-right">
                      <button
                        type="button"
                        phx-click="remove_line"
                        phx-value-index={index}
                        class="text-xs text-red-500 hover:text-red-600"
                      >
                        Премахни
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%= if @invoice_lines == [] do %>
              <div class="text-center py-8 text-sm text-gray-500">
                Няма добавени артикули. Натиснете "Добави ред" за да добавите.
              </div>
            <% end %>
          </div>

          <!-- Обобщение -->
          <div class="mt-4 flex justify-end">
            <div class="w-64 space-y-2">
              <div class="flex justify-between text-sm">
                <span class="text-gray-600">Сума без ДДС:</span>
                <span class="font-medium"><%= calculate_subtotal(@invoice_lines) %> BGN</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-600">ДДС:</span>
                <span class="font-medium"><%= calculate_tax(@invoice_lines) %> BGN</span>
              </div>
              <div class="flex justify-between text-base font-semibold border-t pt-2">
                <span>Общо:</span>
                <span><%= calculate_total(@invoice_lines) %> BGN</span>
              </div>
            </div>
          </div>
        </div>

        <div>
          <label for="notes" class="block text-sm font-medium text-gray-700">
            Забележки
          </label>
          <textarea
            name="invoice[notes]"
            id="notes"
            rows="3"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          ><%= Phoenix.HTML.Form.input_value(@form, :notes) %></textarea>
        </div>

        <!-- ДДС информация -->
        <div class="border-t pt-6">
          <h3 class="text-sm font-semibold text-gray-800 mb-4">ДДС информация (ППЗДДС)</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label for="vat_document_type" class="block text-sm font-medium text-gray-700">
                Вид документ <span class="text-red-500">*</span>
              </label>
              <select
                name="invoice[vat_document_type]"
                id="vat_document_type"
                required
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Изберете вид документ...</option>
                <%= for {code, name} <- CyberCore.Sales.Invoice.vat_document_types() do %>
                  <option
                    value={code}
                    selected={Phoenix.HTML.Form.input_value(@form, :vat_document_type) == code}
                  >
                    <%= code %> - <%= name %>
                  </option>
                <% end %>
              </select>
              <%= if @form && @form.errors[:vat_document_type] do %>
                <p class="mt-2 text-sm text-red-600">
                  <%= translate_error(@form.errors[:vat_document_type]) %>
                </p>
              <% end %>
            </div>

            <div>
              <label for="vat_sales_operation" class="block text-sm font-medium text-gray-700">
                Операция при продажба
              </label>
              <select
                name="invoice[vat_sales_operation]"
                id="vat_sales_operation"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Не е приложимо</option>
                <%= for {code, name} <- CyberCore.Sales.Invoice.vat_sales_operations() do %>
                  <option
                    value={code}
                    selected={Phoenix.HTML.Form.input_value(@form, :vat_sales_operation) == code}
                  >
                    <%= code %> - <%= name %>
                  </option>
                <% end %>
              </select>
            </div>

            <div>
              <label for="vat_purchase_operation" class="block text-sm font-medium text-gray-700">
                Операция при покупка
              </label>
              <select
                name="invoice[vat_purchase_operation]"
                id="vat_purchase_operation"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="">Не е приложимо</option>
                <%= for {code, name} <- CyberCore.Sales.Invoice.vat_purchase_operations() do %>
                  <option
                    value={code}
                    selected={Phoenix.HTML.Form.input_value(@form, :vat_purchase_operation) == code}
                  >
                    <%= code %> - <%= name %>
                  </option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="mt-4 border-t pt-4">
             <h4 class="text-sm font-medium text-gray-800 mb-2">OSS Режим (Режим в съюза)</h4>
            <div class="flex items-start">
              <div class="flex h-6 items-center">
                <input
                  id="oss_enabled"
                  name="invoice[oss_enabled]"
                  type="checkbox"
                  phx-change="validate"
                  checked={Phoenix.HTML.Form.input_value(@form, :oss_country) != nil}
                  class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                />
              </div>
              <div class="ml-3 text-sm leading-6">
                <label for="oss_enabled" class="font-medium text-gray-900">
                  Активиране на OSS режим
                </label>
                <p class="text-gray-500">За доставки на услуги или стоки към крайни потребители в ЕС.</p>
              </div>
            </div>

            <%= if Phoenix.HTML.Form.input_value(@form, :oss_country) != nil or (Map.get(@form.params, "oss_enabled") == "on") do %>
              <div class="mt-4">
                <label for="oss_country" class="block text-sm font-medium text-gray-700">
                  Държава членка на потребление
                </label>
                <select
                  name="invoice[oss_country]"
                  id="oss_country"
                  phx-change="select_oss_country"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                >
                  <option value="">Изберете държава...</option>
                  <%= for {code, name} <- eu_countries() do %>
                    <option
                      value={code}
                      selected={Phoenix.HTML.Form.input_value(@form, :oss_country) == code}
                    >
                      <%= name %> (<%= code %>)
                    </option>
                  <% end %>
                </select>
              </div>
            <% end %>
          </div>
        </div>

        <%= if show_vat_reason?(assigns) do %>
          <div class="mt-4">
            <label for="vat_reason" class="block text-sm font-medium text-gray-700">
              Основание за неначисляване на ДДС <span class="text-red-500">*</span>
            </label>
            <select
              name="invoice[vat_reason]"
              id="vat_reason"
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <option value="">Изберете основание...</option>
              <%= for {code, description} <- CyberCore.Sales.Invoice.vat_zero_reasons() do %>
                <option
                  value={code}
                  selected={Phoenix.HTML.Form.input_value(@form, :vat_reason) == code}
                >
                  <%= description %>
                </option>
              <% end %>
            </select>
            <p class="mt-2 text-sm text-gray-500">
              При избор на "Друго основание" посочете детайли в забележките.
            </p>
          </div>
        <% end %>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <button
            type="button"
            phx-click={JS.patch(~p"/invoices")}
            class="text-sm font-semibold leading-6 text-gray-900 hover:text-gray-700"
          >
            Отказ
          </button>
          <button
            type="submit"
            name="action"
            value="print"
            class="rounded-md bg-gray-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-gray-500"
          >
            Печат
          </button>
          <button
            type="submit"
            name="action"
            value="save"
            phx-disable-with="Записване..."
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Запис
          </button>
        </div>
      </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Фактури</h1>
          <p class="mt-2 text-sm text-gray-700">
            Списък със всички издадени фактури
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/invoices/new"}
            class="inline-flex items-center justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
          >
            + Нова фактура
          </.link>
        </div>
      </div>

      <!-- Филтри -->
      <div class="mt-6 space-y-4">
        <!-- Търсене -->
        <div class="flex flex-col sm:flex-row gap-4">
          <div class="flex-1">
            <form phx-change="search">
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder="Търсене по номер или клиент..."
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
            </form>
          </div>

          <!-- Дати -->
          <form phx-change="filter_dates" class="flex gap-2">
            <input
              type="date"
              name="from"
              value={@date_from || ""}
              placeholder="От дата"
              class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
            <input
              type="date"
              name="to"
              value={@date_to || ""}
              placeholder="До дата"
              class="block rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </form>
        </div>

        <!-- Статус филтър -->
        <div class="flex flex-wrap gap-2">
          <button
            phx-click="filter_status"
            phx-value-status="all"
            class={"px-4 py-2 text-sm font-medium rounded-md " <> if @filter_status == "all", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"}
          >
            Всички
          </button>
          <button
            phx-click="filter_status"
            phx-value-status="draft"
            class={"px-4 py-2 text-sm font-medium rounded-md " <> if @filter_status == "draft", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"}
          >
            Чернови
          </button>
          <button
            phx-click="filter_status"
            phx-value-status="issued"
            class={"px-4 py-2 text-sm font-medium rounded-md " <> if @filter_status == "issued", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"}
          >
            Издадени
          </button>
          <button
            phx-click="filter_status"
            phx-value-status="paid"
            class={"px-4 py-2 text-sm font-medium rounded-md " <> if @filter_status == "paid", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"}
          >
            Платени
          </button>
          <button
            phx-click="filter_status"
            phx-value-status="overdue"
            class={"px-4 py-2 text-sm font-medium rounded-md " <> if @filter_status == "overdue", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"}
          >
            Просрочени
          </button>
        </div>
      </div>

      <!-- Таблица -->
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Номер
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Вид документ
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Клиент
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Дата
                    </th>
                    <th class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Сума
                    </th>
                    <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Статус
                    </th>
                    <th class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Действия</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for invoice <- @invoices do %>
                    <tr class="hover:bg-gray-50">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <.link navigate={~p"/invoices/#{invoice}"} class="text-indigo-600 hover:text-indigo-900">
                          <%= invoice.invoice_no %>
                        </.link>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if invoice.vat_document_type do %>
                          <span class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
                            <%= invoice.vat_document_type %> - <%= Map.get(CyberCore.Sales.Invoice.vat_document_types(), invoice.vat_document_type, "N/A") %>
                          </span>
                        <% else %>
                          <span class="text-gray-400">—</span>
                        <% end %>
                      </td>
                      <td class="px-3 py-4 text-sm text-gray-900">
                        <%= invoice.billing_name %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= Calendar.strftime(invoice.issue_date, "%d.%m.%Y") %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                        <%= Decimal.to_string(invoice.total_amount, :normal) %>
                        <%= invoice.currency %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <.status_badge status={invoice.status} />
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <div class="flex items-center justify-end gap-3">
                          <.link
                            navigate={~p"/invoices/#{invoice}"}
                            class="text-indigo-600 hover:text-indigo-900"
                          >
                            Преглед
                          </.link>

                          <.link
                            patch={~p"/invoices/#{invoice}/edit"}
                            class="text-indigo-600 hover:text-indigo-900"
                          >
                            Редактирай
                          </.link>

                          <%= if invoice.status == "draft" do %>
                            <button
                              type="button"
                              phx-click="issue_invoice"
                              phx-value-id={invoice.id}
                              data-confirm="Издаване на фактурата ще я регистрира автоматично в ДДС дневник продажби. Продължаване?"
                              class="text-green-600 hover:text-green-900"
                            >
                              Издай
                            </button>
                          <% end %>

                          <%= if invoice.status == "issued" do %>
                            <button
                              type="button"
                              phx-click="mark_paid"
                              phx-value-id={invoice.id}
                              data-confirm="Маркирай фактурата като платена?"
                              class="text-blue-600 hover:text-blue-900"
                            >
                              Платена
                            </button>
                          <% end %>

                          <%= if invoice.status in ["issued", "paid", "partially_paid", "overdue"] do %>
                            <button
                              type="button"
                              phx-click="revert_to_draft"
                              phx-value-id={invoice.id}
                              data-confirm="Връщането към чернова ще премахне фактурата от ДДС дневник. Продължаване?"
                              class="text-orange-600 hover:text-orange-900"
                            >
                              → Чернова
                            </button>
                          <% end %>

                          <a
                            href="#"
                            phx-click="delete"
                            phx-value-id={invoice.id}
                            data-confirm="Сигурни ли сте, че искате да изтриете тази фактура?"
                            class="text-red-600 hover:text-red-900"
                          >
                            Изтрий
                          </a>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if @invoices == [] do %>
                <div class="text-center py-12">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">Няма фактури</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Започнете като създадете нова фактура.
                  </p>
                  <div class="mt-6">
                    <.link
                      navigate={~p"/invoices/new"}
                      class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                    >
                      + Нова фактура
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="contact-search-modal"
      show={@show_contact_search_modal}
      title="Търсене на клиент"
      search_fun={&CyberCore.Contacts.search_contacts(1, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:vat_number, "text-sm text-gray-600", fn v -> "ДДС: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:contact_id}
    />

    <.live_component
      module={CyberWeb.Components.SearchModal}
      id="product-search-modal"
      show={@show_product_search_modal}
      title="Търсене на продукт"
      search_fun={&CyberCore.Inventory.search_products(1, &1)}
      display_fields={[
        {:name, "font-bold", fn v -> v end},
        {:sku, "text-sm text-gray-600", fn v -> "SKU: " <> to_string(v || "") end}
      ]}
      caller={self()}
      field={:product_id}
    />
    """
  end

  defp status_badge(%{status: "draft"} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-gray-100 px-2 text-xs font-semibold leading-5 text-gray-800">
      Чернова
    </span>
    """
  end

  defp status_badge(%{status: "issued"} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-blue-100 px-2 text-xs font-semibold leading-5 text-blue-800">
      Издадена
    </span>
    """
  end

  defp status_badge(%{status: "paid"} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-green-100 px-2 text-xs font-semibold leading-5 text-green-800">
      Платена
    </span>
    """
  end

  defp status_badge(%{status: "partially_paid"} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-yellow-100 px-2 text-xs font-semibold leading-5 text-yellow-800">
      Частично платена
    </span>
    """
  end

  defp status_badge(%{status: "overdue"} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-red-100 px-2 text-xs font-semibold leading-5 text-red-800">
      Просрочена
    </span>
    """
  end

  defp status_badge(%{status: _} = assigns) do
    ~H"""
    <span class="inline-flex rounded-full bg-gray-100 px-2 text-xs font-semibold leading-5 text-gray-800">
      <%= @status %>
    </span>
    """
  end

  defp translate_error({msg, _opts}), do: msg
  defp translate_error(msg) when is_binary(msg), do: msg

  defp calculate_subtotal(lines) do
    lines
    |> Enum.reduce(Decimal.new(0), fn line, acc ->
      qty = to_decimal(line.quantity)
      price = to_decimal(line.unit_price)
      discount = to_decimal(line[:discount_percent] || 0)

      gross = Decimal.mult(qty, price)
      discount_amount = Decimal.mult(gross, Decimal.div(discount, Decimal.new(100)))
      subtotal = Decimal.sub(gross, discount_amount)
      Decimal.add(acc, subtotal)
    end)
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp calculate_tax(lines) do
    lines
    |> Enum.reduce(Decimal.new(0), fn line, acc ->
      qty = to_decimal(line.quantity)
      price = to_decimal(line.unit_price)
      discount = to_decimal(line[:discount_percent] || 0)
      tax_rate = to_decimal(line.tax_rate)

      gross = Decimal.mult(qty, price)
      discount_amount = Decimal.mult(gross, Decimal.div(discount, Decimal.new(100)))
      subtotal = Decimal.sub(gross, discount_amount)
      tax = Decimal.mult(subtotal, Decimal.div(tax_rate, Decimal.new(100)))
      Decimal.add(acc, tax)
    end)
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  defp calculate_total(lines) do
    lines
    |> Enum.reduce(Decimal.new(0), fn line, acc ->
      qty = to_decimal(line.quantity)
      price = to_decimal(line.unit_price)
      discount = to_decimal(line[:discount_percent] || 0)
      tax_rate = to_decimal(line.tax_rate)

      gross = Decimal.mult(qty, price)
      discount_amount = Decimal.mult(gross, Decimal.div(discount, Decimal.new(100)))
      subtotal = Decimal.sub(gross, discount_amount)
      tax = Decimal.mult(subtotal, Decimal.div(tax_rate, Decimal.new(100)))
      total = Decimal.add(subtotal, tax)
      Decimal.add(acc, total)
    end)
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
  end

  # Конвертира lines params от map (%{"0" => %{...}}) към list
  defp convert_lines_params(lines_params) when is_map(lines_params) do
    lines_params
    |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
    |> Enum.map(fn {_index, line} ->
      %{
        "product_id" => Map.get(line, "product_id"),
        "description" => Map.get(line, "description", ""),
        "quantity" => Map.get(line, "quantity", "1"),
        "unit_price" => Map.get(line, "unit_price", "0"),
        "tax_rate" => Map.get(line, "tax_rate", "20"),
        "discount_percent" => Map.get(line, "discount_percent", "0")
      }
    end)
  end

  defp convert_lines_params(lines_params) when is_list(lines_params), do: lines_params
  defp convert_lines_params(_), do: []

  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(%Decimal{} = value), do: value

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp load_bank_accounts do
    CyberCore.Bank.list_bank_accounts(1, is_active: true)
  end

  defp eu_countries do
    [
      {"AT", "Австрия"},
      {"BE", "Белгия"},
      {"BG", "България"},
      {"HR", "Хърватия"},
      {"CY", "Кипър"},
      {"CZ", "Чехия"},
      {"DK", "Дания"},
      {"EE", "Естония"},
      {"FI", "Финландия"},
      {"FR", "Франция"},
      {"DE", "Германия"},
      {"GR", "Гърция"},
      {"HU", "Унгария"},
      {"IE", "Ирландия"},
      {"IT", "Италия"},
      {"LV", "Латвия"},
      {"LT", "Литва"},
      {"LU", "Люксембург"},
      {"MT", "Малта"},
      {"NL", "Нидерландия"},
      {"PL", "Полша"},
      {"PT", "Португалия"},
      {"RO", "Румъния"},
      {"SK", "Словакия"},
      {"SI", "Словения"},
      {"ES", "Испания"},
      {"SE", "Швеция"}
    ]
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp form_params(nil), do: %{}
  defp form_params(form), do: form.params || %{}

  defp get_product_name(product_id) do
    if product_id do
      product = CyberCore.Inventory.get_product!(1, product_id)
      product.name
    else
      ""
    end
  end

  defp show_vat_reason?(%{invoice_lines: invoice_lines, settings: settings}) do
    # Check if invoice_lines is a list of maps, and if any of those maps has a tax_rate of 0
    is_zero_rate_line =
      Enum.any?(invoice_lines, fn line ->
        case line do
          %{tax_rate: rate} -> to_decimal(rate) == Decimal.new(0)
          _ -> false
        end
      end)

    settings && settings.is_vat_registered && is_zero_rate_line
  end
end
