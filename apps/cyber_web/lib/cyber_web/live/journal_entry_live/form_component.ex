defmodule CyberWeb.JournalEntryLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting
  alias CyberCore.Contacts
  alias CyberCore.Currencies
  alias Decimal, as: D

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    tenant_id = assigns.tenant_id
    accounts = Accounting.list_accounts(tenant_id)
    contacts = Contacts.list_contacts(tenant_id, [])
    currencies = Currencies.list_currencies(%{is_active: true})

    socket =
      socket
      |> assign(assigns)
      |> assign(:accounts, accounts)
      |> assign(:contacts, contacts)
      |> assign(:currencies, currencies)
      |> assign_new(:entry_lines, fn ->
        [
          %{
            id: 1,
            account_id: nil,
            contact_id: nil,
            is_analytical: false,
            debit: "",
            credit: "",
            description: "",
            currency_code: "BGN",
            currency_amount: "",
            exchange_rate: "1.0"
          }
        ]
      end)
      |> assign_new(:document_date, fn -> Date.utc_today() end)
      |> assign_new(:vat_date, fn -> Date.utc_today() end)
      |> assign_new(:accounting_date, fn -> Date.utc_today() end)
      |> assign_new(:description, fn -> "" end)
      |> assign_new(:entry_number, fn -> "" end)
      |> calculate_totals()

    {:ok, socket}
  end

  @impl true
  def handle_event("add_line", _params, socket) do
    new_id = length(socket.assigns.entry_lines) + 1

    new_line = %{
      id: new_id,
      account_id: nil,
      contact_id: nil,
      is_analytical: false,
      debit: "",
      credit: "",
      description: "",
      currency_code: "BGN",
      currency_amount: "",
      exchange_rate: "1.0"
    }

    socket =
      socket
      |> assign(:entry_lines, socket.assigns.entry_lines ++ [new_line])
      |> calculate_totals()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_line", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    lines = Enum.reject(socket.assigns.entry_lines, fn line -> line.id == id end)

    socket =
      socket
      |> assign(:entry_lines, lines)
      |> calculate_totals()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_line", params, socket) do
    id = String.to_integer(params["id"])
    field = String.to_existing_atom(params["field"])
    value = params["value"]

    lines =
      if field == :account_id do
        account = Enum.find(socket.assigns.accounts, &(&1.id == String.to_integer(value)))

        Enum.map(socket.assigns.entry_lines, fn line ->
          if line.id == id do
            line
            |> Map.put(field, value)
            |> Map.put(:is_analytical, account && account.is_analytical)
          else
            line
          end
        end)
      else
        Enum.map(socket.assigns.entry_lines, fn line ->
          if line.id == id do
            Map.put(line, field, value)
          else
            line
          end
        end)
      end

    socket =
      socket
      |> assign(:entry_lines, lines)
      |> calculate_totals()

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", params, socket) do
    lines = socket.assigns.entry_lines

    invalid_line? =
      Enum.any?(lines, fn line ->
        line.is_analytical and (is_nil(line.contact_id) or line.contact_id == "")
      end)

    if invalid_line? do
      {:noreply, assign(socket, :error, "Моля, изберете контрагент за всички аналитични сметки.")}
    else
      entry_attrs = %{
        tenant_id: socket.assigns.tenant_id,
        document_date: params["document_date"],
        vat_date: params["vat_date"],
        accounting_date: params["accounting_date"],
        description: params["description"],
        entry_number: params["entry_number"],
        total_amount: socket.assigns.total_debit,
        # TODO: Get from session
        created_by_id: 1
      }

      lines_attrs =
        lines
        |> Enum.map(fn line ->
          %{
            account_id: line.account_id && String.to_integer(line.account_id),
            contact_id: line.contact_id && String.to_integer(line.contact_id),
            debit_amount: parse_decimal(line.debit),
            credit_amount: parse_decimal(line.credit),
            description: line.description,
            currency_code: line.currency_code || "BGN",
            currency_amount: parse_decimal(line.currency_amount),
            exchange_rate: parse_decimal(line.exchange_rate)
          }
        end)
        |> Enum.reject(fn line -> is_nil(line.account_id) end)

      case Accounting.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
        {:ok, _entry} ->
          send(self(), {:entry_created, "Записът е създаден успешно"})
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, assign(socket, :error, "Грешка: #{inspect(reason)}")}
      end
    end
  end

  defp calculate_totals(socket) do
    {total_debit, total_credit} =
      socket.assigns.entry_lines
      |> Enum.reduce({D.new(0), D.new(0)}, fn line, {debit_acc, credit_acc} ->
        debit = parse_decimal(line.debit)
        credit = parse_decimal(line.credit)
        {D.add(debit_acc, debit), D.add(credit_acc, credit)}
      end)

    balanced = D.equal?(total_debit, total_credit) and D.gt?(total_debit, 0)

    socket
    |> assign(:total_debit, total_debit)
    |> assign(:total_credit, total_credit)
    |> assign(:is_balanced, balanced)
  end

  defp parse_decimal(""), do: D.new(0)
  defp parse_decimal(nil), do: D.new(0)

  defp parse_decimal(value) when is_binary(value) do
    case D.cast(value) do
      {:ok, decimal} -> decimal
      :error -> D.new(0)
    end
  end

  defp format_decimal(amount) do
    D.to_string(amount, :normal)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold text-gray-900 mb-4">
        <%= @title %>
      </h2>

      <form phx-submit="save" phx-target={@myself}>
        <!-- Header fields -->
        <div class="grid grid-cols-3 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Номер запис</label>
            <input
              type="text"
              name="entry_number"
              value={@entry_number}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Док. дата *</label>
            <input
              type="date"
              name="document_date"
              value={Date.to_iso8601(@document_date)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">ДДС дата</label>
            <input
              type="date"
              name="vat_date"
              value={Date.to_iso8601(@vat_date)}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Счет. дата *</label>
            <input
              type="date"
              name="accounting_date"
              value={Date.to_iso8601(@accounting_date)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Описание *</label>
            <input
              type="text"
              name="description"
              value={@description}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <!-- Lines table -->
        <div class="mb-4">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-medium text-gray-900">Редове:</h3>
            <button
              type="button"
              phx-click="add_line"
              phx-target={@myself}
              class="rounded-md bg-indigo-600 px-3 py-1 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              + Добави ред
            </button>
          </div>

          <div class="overflow-x-auto shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th class="py-2 pl-4 pr-2 text-left text-xs font-medium text-gray-500 sm:pl-6">
                    Сметка *
                  </th>
                  <th class="px-2 py-2 text-left text-xs font-medium text-gray-500">Контрагент</th>
                  <th class="px-2 py-2 text-left text-xs font-medium text-gray-500">Валута</th>
                  <th class="px-2 py-2 text-right text-xs font-medium text-gray-500">Сума във вал.</th>
                  <th class="px-2 py-2 text-right text-xs font-medium text-gray-500">Курс</th>
                  <th class="px-2 py-2 text-right text-xs font-medium text-gray-500">Дебит BGN</th>
                  <th class="px-2 py-2 text-right text-xs font-medium text-gray-500">Кредит BGN</th>
                  <th class="px-2 py-2 text-left text-xs font-medium text-gray-500">Описание</th>
                  <th class="py-2 pl-2 pr-4 sm:pr-6">
                    <span class="sr-only">Действия</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                <%= for line <- @entry_lines do %>
                  <tr>
                    <td class="py-2 pl-4 pr-2 sm:pl-6">
                      <select
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="account_id"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs"
                      >
                        <option value="">Избери...</option>
                        <%= for account <- @accounts do %>
                          <option value={account.id} selected={line.account_id == to_string(account.id)}>
                            <%= account.code %> - <%= account.name %>
                          </option>
                        <% end %>
                      </select>
                    </td>
                    <td class="px-2 py-2">
                      <%= if line.is_analytical do %>
                        <select
                          phx-change="update_line"
                          phx-target={@myself}
                          phx-value-id={line.id}
                          phx-value-field="contact_id"
                          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs"
                          required
                        >
                          <option value="">Избери...</option>
                          <%= for contact <- @contacts do %>
                            <option value={contact.id} selected={line.contact_id == to_string(contact.id)}>
                              <%= contact.name %>
                            </option>
                          <% end %>
                        </select>
                      <% else %>
                        <span class="text-gray-400">-</span>
                      <% end %>
                    </td>
                    <td class="px-2 py-2">
                      <select
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="currency_code"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs"
                      >
                        <%= for currency <- @currencies do %>
                          <option value={currency.code} selected={line.currency_code == currency.code}>
                            <%= currency.code %>
                          </option>
                        <% end %>
                      </select>
                    </td>
                    <td class="px-2 py-2">
                      <input
                        type="number"
                        step="0.01"
                        value={line.currency_amount}
                        placeholder="Опция"
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="currency_amount"
                        class="block w-20 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs text-right"
                      />
                    </td>
                    <td class="px-2 py-2">
                      <input
                        type="number"
                        step="0.000001"
                        value={line.exchange_rate}
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="exchange_rate"
                        class="block w-20 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs text-right"
                      />
                    </td>
                    <td class="px-2 py-2">
                      <input
                        type="number"
                        step="0.01"
                        value={line.debit}
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="debit"
                        class="block w-24 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs text-right"
                      />
                    </td>
                    <td class="px-2 py-2">
                      <input
                        type="number"
                        step="0.01"
                        value={line.credit}
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="credit"
                        class="block w-24 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs text-right"
                      />
                    </td>
                    <td class="px-2 py-2">
                      <input
                        type="text"
                        value={line.description}
                        phx-change="update_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        phx-value-field="description"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-xs"
                      />
                    </td>
                    <td class="py-2 pl-2 pr-4 text-right sm:pr-6">
                      <button
                        type="button"
                        phx-click="remove_line"
                        phx-target={@myself}
                        phx-value-id={line.id}
                        class="text-red-600 hover:text-red-900 text-xs"
                      >
                        Изтрий
                      </button>
                    </td>
                  </tr>
                <% end %>

                <!-- Totals row -->
                <tr class="bg-gray-50 font-semibold">
                  <td colspan="5" class="py-2 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">ОБЩО:</td>
                  <td class="px-2 py-2 text-sm text-right">
                    <span class={[
                      "font-mono",
                      if(@is_balanced, do: "text-green-700", else: "text-red-700")
                    ]}>
                      <%= format_decimal(@total_debit) %>
                    </span>
                  </td>
                  <td class="px-2 py-2 text-sm text-right">
                    <span class={[
                      "font-mono",
                      if(@is_balanced, do: "text-green-700", else: "text-red-700")
                    ]}>
                      <%= format_decimal(@total_credit) %>
                    </span>
                  </td>
                  <td colspan="2" class="px-2 py-2 text-sm">
                    <%= if @is_balanced do %>
                      <span class="text-green-700">✓ Балансиран</span>
                    <% else %>
                      <span class="text-red-700">✗ Небалансиран</span>
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%= if assigns[:error] do %>
          <div class="rounded-md bg-red-50 p-4 mb-4">
            <p class="text-sm text-red-800"><%= @error %></p>
          </div>
        <% end %>

        <!-- Action buttons -->
        <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
          <button
            type="submit"
            disabled={not @is_balanced}
            class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 sm:ml-3 sm:w-auto disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Запази
          </button>
          <.link
            navigate={~p"/journal-entries"}
            class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
          >
            Отказ
          </.link>
        </div>
      </form>
    </div>
    """
  end
end
