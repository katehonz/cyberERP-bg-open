defmodule CyberWeb.VatPurchaseRegisterLive.FormComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting.Vat
  alias CyberCore.Sales.Invoice
  alias Decimal, as: D

  @impl true
  def update(assigns, socket) do
    entry = assigns.entry

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:document_date, fn -> entry.document_date || Date.utc_today() end)
      |> assign_new(:tax_event_date, fn -> entry.tax_event_date || Date.utc_today() end)
      |> assign_new(:document_type, fn -> entry.document_type || "01" end)
      |> assign_new(:document_number, fn -> entry.document_number || "" end)
      |> assign_new(:purchase_operation, fn -> entry.purchase_operation || "2" end)
      |> assign_new(:supplier_name, fn -> entry.supplier_name || "" end)
      |> assign_new(:supplier_vat_number, fn -> entry.supplier_vat_number || "" end)
      |> assign_new(:supplier_eik, fn -> entry.supplier_eik || "" end)
      |> assign_new(:taxable_base, fn -> entry.taxable_base || D.new(0) end)
      |> assign_new(:vat_rate, fn -> entry.vat_rate || D.new(20) end)
      |> assign_new(:vat_amount, fn -> entry.vat_amount || D.new(0) end)
      |> assign_new(:is_deductible, fn -> entry.is_deductible || true end)
      |> assign_new(:notes, fn -> entry.notes || "" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("calculate_vat", _params, socket) do
    taxable_base = socket.assigns.taxable_base
    vat_rate = socket.assigns.vat_rate

    vat_amount =
      D.mult(taxable_base, vat_rate)
      |> D.div(100)
      |> D.round(2)

    {:noreply, assign(socket, :vat_amount, vat_amount)}
  end

  @impl true
  def handle_event("save", params, socket) do
    attrs = %{
      tenant_id: socket.assigns.tenant_id,
      period_year: socket.assigns.period_year,
      period_month: socket.assigns.period_month,
      document_date: params["document_date"],
      tax_event_date: params["tax_event_date"],
      document_type: params["document_type"],
      document_number: params["document_number"],
      purchase_operation: params["purchase_operation"],
      supplier_name: params["supplier_name"],
      supplier_vat_number: params["supplier_vat_number"],
      supplier_eik: params["supplier_eik"],
      taxable_base: parse_decimal(params["taxable_base"]),
      vat_rate: parse_decimal(params["vat_rate"]),
      vat_amount: parse_decimal(params["vat_amount"]),
      is_deductible: params["is_deductible"] == "true",
      notes: params["notes"]
    }

    result =
      if socket.assigns.entry.id do
        Vat.update_purchase_register_entry(socket.assigns.entry, attrs)
      else
        Vat.create_purchase_register_entry(attrs)
      end

    case result do
      {:ok, _entry} ->
        message = if socket.assigns.entry.id, do: "Записът е обновен", else: "Записът е създаден"
        send(self(), {:entry_saved, message})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :error, "Грешка: #{inspect(changeset.errors)}")}
    end
  end

  defp parse_decimal(""), do: D.new(0)
  defp parse_decimal(nil), do: D.new(0)

  defp parse_decimal(value) when is_binary(value) do
    case D.cast(value) do
      {:ok, decimal} -> decimal
      :error -> D.new(0)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold text-gray-900 mb-4">
        <%= if @entry.id, do: "Редактиране", else: "Нов запис" %> в дневник покупки
      </h2>

      <form phx-submit="save" phx-target={@myself}>
        <div class="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Дата на документ *</label>
            <input
              type="date"
              name="document_date"
              value={Date.to_iso8601(@document_date)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Данъчно събитие *</label>
            <input
              type="date"
              name="tax_event_date"
              value={Date.to_iso8601(@tax_event_date)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Тип документ *</label>
            <select
              name="document_type"
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <%= for {code, name} <- Invoice.vat_document_types() do %>
                <option value={code} selected={code == @document_type}>
                  <%= code %> - <%= name %>
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Номер документ *</label>
            <input
              type="text"
              name="document_number"
              value={@document_number}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Операция</label>
            <select
              name="purchase_operation"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <%= for {code, name} <- Invoice.vat_purchase_operations() do %>
                <option value={code} selected={code == @purchase_operation}>
                  <%= code %> - <%= name %>
                </option>
              <% end %>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Име на доставчик *</label>
            <input
              type="text"
              name="supplier_name"
              value={@supplier_name}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">ДДС номер</label>
            <input
              type="text"
              name="supplier_vat_number"
              value={@supplier_vat_number}
              placeholder="BG123456789"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">ЕИК/Булстат</label>
            <input
              type="text"
              name="supplier_eik"
              value={@supplier_eik}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Данъчна основа *</label>
            <input
              type="number"
              step="0.01"
              name="taxable_base"
              value={Decimal.to_string(@taxable_base, :normal)}
              phx-blur="calculate_vat"
              phx-target={@myself}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">ДДС % *</label>
            <input
              type="number"
              step="0.01"
              name="vat_rate"
              value={Decimal.to_string(@vat_rate, :normal)}
              phx-blur="calculate_vat"
              phx-target={@myself}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Сума ДДС *</label>
            <input
              type="number"
              step="0.01"
              name="vat_amount"
              value={Decimal.to_string(@vat_amount, :normal)}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>
        </div>

        <div class="mb-4">
          <label class="flex items-center">
            <input
              type="checkbox"
              name="is_deductible"
              value="true"
              checked={@is_deductible}
              class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            />
            <span class="ml-2 text-sm text-gray-700">ДДС за приспадане</span>
          </label>
          <p class="mt-1 text-xs text-gray-500">
            Отметнете ако ДДС по този документ може да се приспадне
          </p>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700">Забележки</label>
          <textarea
            name="notes"
            rows="3"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          ><%= @notes %></textarea>
        </div>

        <%= if assigns[:error] do %>
          <div class="rounded-md bg-red-50 p-4 mb-4">
            <p class="text-sm text-red-800"><%= @error %></p>
          </div>
        <% end %>

        <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
          <button
            type="submit"
            class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto"
          >
            Запази
          </button>
          <.link
            navigate={~p"/vat/purchase-register"}
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
