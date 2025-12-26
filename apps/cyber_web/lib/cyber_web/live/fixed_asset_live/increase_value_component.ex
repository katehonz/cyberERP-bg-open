defmodule CyberWeb.FixedAssetLive.IncreaseValueComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting
  alias CyberCore.Accounting.FixedAssets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-semibold text-zinc-900 mb-4">
        Увеличаване на стойността на актив
      </h3>

      <div class="mb-6 rounded-lg bg-blue-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm text-blue-700">
              <strong><%= @asset.name %></strong> (<%= @asset.code %>)
            </p>
            <p class="text-sm text-blue-600 mt-1">
              Текуща придобивна стойност: <strong><%= format_currency(@asset.acquisition_cost) %></strong>
            </p>
          </div>
        </div>
      </div>

      <.form
        for={@form}
        id="increase-value-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <!-- Amount -->
          <div>
            <label for="amount" class="block text-sm font-medium text-zinc-700">
              Сума на увеличението *
            </label>
            <div class="mt-1 relative rounded-md shadow-sm">
              <input
                type="number"
                step="0.01"
                min="0.01"
                name="amount"
                id="amount"
                value={@form[:amount]}
                class="block w-full rounded-md border-zinc-300 pr-12 focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                placeholder="0.00"
                required
              />
              <div class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                <span class="text-zinc-500 sm:text-sm">лв.</span>
              </div>
            </div>
            <%= if @errors[:amount] do %>
              <p class="mt-2 text-sm text-red-600"><%= @errors[:amount] %></p>
            <% end %>
          </div>

          <!-- Transaction Date -->
          <div>
            <label for="transaction_date" class="block text-sm font-medium text-zinc-700">
              Дата на транзакцията *
            </label>
            <input
              type="date"
              name="transaction_date"
              id="transaction_date"
              value={@form[:transaction_date] || Date.to_string(Date.utc_today())}
              class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              required
            />
            <%= if @errors[:transaction_date] do %>
              <p class="mt-2 text-sm text-red-600"><%= @errors[:transaction_date] %></p>
            <% end %>
          </div>

          <!-- Description -->
          <div>
            <label for="description" class="block text-sm font-medium text-zinc-700">
              Описание на подобрението
            </label>
            <textarea
              name="description"
              id="description"
              rows="3"
              class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="Например: Монтиране на ГБО система, Ремонт на двигател, и т.н."
            ><%= @form[:description] %></textarea>
          </div>

          <!-- Source Account Selection -->
          <div>
            <label for="source_account_id" class="block text-sm font-medium text-zinc-700">
              Сметка източник (Кредит) *
            </label>
            <select
              name="source_account_id"
              id="source_account_id"
              class="mt-1 block w-full rounded-md border-zinc-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              required
            >
              <option value="">Изберете сметка...</option>
              <%= for account <- @available_accounts do %>
                <option value={account.id} selected={@form[:source_account_id] == account.id}>
                  <%= account.code %> - <%= account.name %>
                </option>
              <% end %>
            </select>
            <p class="mt-1 text-xs text-zinc-500">
              Сметката, от която ще бъде кредитирана сумата (напр. Банка, Доставчици)
            </p>
            <%= if @errors[:source_account_id] do %>
              <p class="mt-2 text-sm text-red-600"><%= @errors[:source_account_id] %></p>
            <% end %>
          </div>

          <!-- Regenerate Schedule Checkbox -->
          <div class="flex items-start">
            <div class="flex h-5 items-center">
              <input
                id="regenerate_schedule"
                name="regenerate_schedule"
                type="checkbox"
                checked={@form[:regenerate_schedule]}
                class="h-4 w-4 rounded border-zinc-300 text-indigo-600 focus:ring-indigo-500"
              />
            </div>
            <div class="ml-3 text-sm">
              <label for="regenerate_schedule" class="font-medium text-zinc-700">
                Преизчисли амортизационния график
              </label>
              <p class="text-zinc-500">
                Генерира нов график с новата стойност за остатъка от полезния живот
              </p>
            </div>
          </div>

          <!-- New Value Preview -->
          <%= if @preview_new_value do %>
            <div class="rounded-lg bg-green-50 p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                </div>
                <div class="ml-3 flex-1">
                  <h3 class="text-sm font-medium text-green-800">Нова придобивна стойност</h3>
                  <div class="mt-2 text-sm text-green-700">
                    <p><%= format_currency(@preview_new_value) %></p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Buttons -->
        <div class="mt-6 flex justify-end gap-3">
          <button
            type="button"
            class="inline-flex justify-center rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 shadow-sm hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            phx-click="close_modal"
            phx-target={@myself}
          >
            Отказ
          </button>
          <button
            type="submit"
            class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            disabled={@saving}
          >
            <%= if @saving do %>
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Записване...
            <% else %>
              Запази увеличението
            <% end %>
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{asset: _asset, tenant_id: tenant_id} = assigns, socket) do
    # Load available accounts for source selection
    available_accounts =
      Accounting.list_accounts(tenant_id)
      |> Enum.filter(fn account ->
        account.account_type in ["bank", "payable", "expense"]
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_accounts, available_accounts)
     |> assign(:form, %{})
     |> assign(:errors, %{})
     |> assign(:preview_new_value, nil)
     |> assign(:saving, false)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    errors = validate_form(params, socket.assigns.asset)

    # Calculate preview if amount is valid
    preview_new_value =
      case parse_amount(params["amount"]) do
        {:ok, amount} ->
          Decimal.add(socket.assigns.asset.acquisition_cost, amount)

        _ ->
          nil
      end

    {:noreply,
     socket
     |> assign(:form, params)
     |> assign(:errors, errors)
     |> assign(:preview_new_value, preview_new_value)}
  end

  @impl true
  def handle_event("save", params, socket) do
    errors = validate_form(params, socket.assigns.asset)

    if Enum.empty?(errors) do
      save_increase(socket, params)
    else
      {:noreply, assign(socket, :errors, errors)}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  defp save_increase(socket, params) do
    asset = socket.assigns.asset

    with {:ok, amount} <- parse_amount(params["amount"]),
         {:ok, source_account_id} <- parse_integer(params["source_account_id"]),
         {:ok, transaction_date} <- parse_date(params["transaction_date"]) do
      socket = assign(socket, :saving, true)

      attrs = %{
        amount: amount,
        transaction_date: transaction_date,
        description: params["description"] || "Увеличаване на стойността",
        regenerate_schedule: params["regenerate_schedule"] == "true"
      }

      case FixedAssets.increase_asset_value_with_accounting(asset, attrs, source_account_id) do
        {:ok, {_updated_asset, _transaction, _journal_entry}} ->
          {:noreply,
           socket
           |> put_flash(:info, "Стойността на актива е успешно увеличена")
           |> push_patch(to: socket.assigns.patch)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:error, "Грешка при увеличаване: #{inspect(reason)}")}
      end
    else
      {:error, msg} ->
        {:noreply,
         socket
         |> assign(:errors, %{general: msg})
         |> assign(:saving, false)}
    end
  end

  defp validate_form(params, asset) do
    errors = %{}

    # Validate amount
    errors =
      case parse_amount(params["amount"]) do
        {:ok, amount} ->
          cond do
            Decimal.compare(amount, Decimal.new(0)) != :gt ->
              Map.put(errors, :amount, "Сумата трябва да бъде положително число")

            Decimal.compare(amount, Decimal.new("999999999.99")) == :gt ->
              Map.put(errors, :amount, "Сумата е твърде голяма")

            true ->
              errors
          end

        {:error, _} ->
          Map.put(errors, :amount, "Невалидна сума")
      end

    # Validate transaction date
    errors =
      case parse_date(params["transaction_date"]) do
        {:ok, date} ->
          cond do
            Date.compare(date, asset.acquisition_date) == :lt ->
              Map.put(
                errors,
                :transaction_date,
                "Датата не може да бъде преди датата на придобиване"
              )

            Date.compare(date, Date.utc_today()) == :gt ->
              Map.put(errors, :transaction_date, "Датата не може да бъде в бъдещето")

            true ->
              errors
          end

        {:error, _} ->
          Map.put(errors, :transaction_date, "Невалидна дата")
      end

    # Validate source account
    errors =
      if params["source_account_id"] in [nil, ""] do
        Map.put(errors, :source_account_id, "Моля изберете сметка източник")
      else
        errors
      end

    # Validate asset status
    errors =
      if asset.status == "disposed" do
        Map.put(errors, :general, "Не може да увеличите стойността на изведен актив")
      else
        errors
      end

    errors
  end

  defp parse_amount(nil), do: {:error, "липсва"}
  defp parse_amount(""), do: {:error, "липсва"}

  defp parse_amount(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> {:ok, decimal}
      :error -> {:error, "невалидна"}
    end
  end

  defp parse_date(nil), do: {:error, "липсва"}
  defp parse_date(""), do: {:error, "липсва"}

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "невалидна"}
    end
  end

  defp parse_integer(nil), do: {:error, "липсва"}
  defp parse_integer(""), do: {:error, "липсва"}

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      :error -> {:error, "невалидна"}
    end
  end

  defp format_currency(amount) when is_nil(amount), do: "0.00 лв."

  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_currency_string()
  end

  defp format_currency_string(str) do
    [int_part, dec_part] = String.split(str <> ".00", ".") |> Enum.take(2)

    formatted_int =
      int_part
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(" ")
      |> String.reverse()

    "#{formatted_int}.#{String.pad_trailing(dec_part, 2, "0")} лв."
  end
end
