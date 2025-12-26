defmodule CyberWeb.ProductLive.FormComponent do
  use CyberWeb, :live_component

  import Ecto.Query

  alias CyberCore.Inventory
  alias CyberCore.Inventory.CnNomenclature
  alias CyberCore.Accounting

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">
        <%= @title %>
      </h2>

      <.simple_form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input field={@form[:sku]} label="SKU код" required />
          <.input field={@form[:name]} label="Име на артикул" required />

          <.input
            field={@form[:category]}
            type="select"
            label="Категория"
            options={[
              {"📦 Стока (за търговия)", "goods"},
              {"🔧 Материал (за производство)", "materials"},
              {"🏭 Произведена продукция (от рецепти)", "produced"},
              {"⚙️ Услуга", "services"}
            ]}
            prompt="Изберете категория"
            required
          />

          <.input field={@form[:unit]} label="Мерна единица" placeholder="бр., кг, л, м" />

          <.input field={@form[:price]} type="number" step="0.01" label="Цена" />
          <.input field={@form[:cost]} type="number" step="0.01" label="Себестойност" />

          <.input
            field={@form[:barcode]}
            label="Баркод"
            placeholder="EAN-13, UPC, и др."
          />
          <.input
            field={@form[:tax_rate]}
            type="number"
            step="0.01"
            label="ДДС ставка (%)"
            placeholder="20"
          />

          <.input
            field={@form[:account_id]}
            type="select"
            label="Инвентарна сметка (304, 302, 303)"
            options={@account_options}
            prompt="Изберете сметка"
          />

          <.input
            field={@form[:expense_account_id]}
            type="select"
            label="Сметка за разход (702, 601, 611)"
            options={@account_options}
            prompt="Изберете сметка"
          />

          <.input
            field={@form[:revenue_account_id]}
            type="select"
            label="Сметка за приходи (702 за стоки)"
            options={@account_options}
            prompt="Изберете сметка (ако се продава)"
          />

          <.input
            field={@form[:cn_code_id]}
            type="select"
            label="КН код (Комбинирана номенклатура)"
            options={@cn_code_options}
            prompt="Изберете КН код (опционално)"
          />
        </div>

        <.input
          field={@form[:description]}
          type="textarea"
          label="Описание"
          rows={3}
        />

        <div class="flex items-center gap-4">
          <.input field={@form[:is_active]} type="select" label="Статус" options={[
            {"Активен", "true"},
            {"Неактивен", "false"}
          ]} />

          <.input
            field={@form[:track_inventory]}
            type="select"
            label="Проследяване на наличност"
            options={[
              {"Да", "true"},
              {"Не", "false"}
            ]}
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
  def update(%{product: product} = assigns, socket) do
    changeset = Inventory.change_product(product, %{})

    # Зареждаме счетоводните сметки
    accounts = Accounting.list_accounts(1)

    account_options =
      Enum.map(accounts, fn account ->
        {"#{account.code} - #{account.name}", account.id}
      end)

    # Зареждаме КН кодове (за 2026)
    cn_codes =
      CyberCore.Repo.all(
        from(cn in CnNomenclature,
          where: cn.year == 2026 and cn.is_active == true,
          where: fragment("length(?)", cn.code) >= 4,  # Само детайлни кодове (не раздели/глави)
          order_by: [asc: cn.code],
          limit: 500
        )
      )

    cn_code_options =
      Enum.map(cn_codes, fn cn ->
        desc = cn.description || ""
        label = if String.length(desc) > 50 do
          "#{cn.code} - #{String.slice(desc, 0..47)}..."
        else
          "#{cn.code} - #{desc}"
        end
        {label, cn.id}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:parent, Map.get(assigns, :parent))
     |> assign(:account_options, account_options)
     |> assign(:cn_code_options, cn_code_options)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.product
      |> Inventory.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    save_product(socket, socket.assigns.action, product_params)
  end

  defp save_product(socket, :edit, product_params) do
    case Inventory.update_product(socket.assigns.product, product_params) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Артикулът беше актуализиран успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_product(socket, :new, product_params) do
    # Добавяме tenant_id
    product_params = Map.put(product_params, "tenant_id", socket.assigns.current_tenant_id)

    case Inventory.create_product(product_params) do
      {:ok, product} ->
        if socket.assigns.parent do
          send(socket.assigns.parent, {:product_created, product})
          {:noreply, socket}
        else
          {:noreply,
           socket
           |> put_flash(:info, "Артикулът беше създаден успешно")
           |> push_patch(to: socket.assigns.patch)}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
