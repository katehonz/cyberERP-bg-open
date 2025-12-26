defmodule CyberWeb.RecipeLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Manufacturing
  alias CyberCore.Inventory
  alias Decimal, as: D

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    products = Inventory.list_products(@tenant_id)

    {:ok,
     socket
     |> assign(:page_title, "Производствени рецепти")
     |> assign(:recipes, [])
     |> assign(:recipe, nil)
     |> assign(:form, nil)
     |> assign(:recipe_lines, [new_line_template()])
     |> assign(:materials_totals, materials_totals([]))
     |> assign(:filter_active, "all")
     |> assign(:search_query, "")
     |> assign(:products, products)
     |> load_recipes()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:recipe, nil)
    |> assign(:form, nil)
    |> assign(:recipe_lines, [new_line_template()])
    |> assign(:materials_totals, materials_totals([]))
  end

  defp apply_action(socket, :new, _params) do
    recipe = %Manufacturing.Recipe{
      code: "REC-" <> Integer.to_string(System.unique_integer([:positive])),
      is_active: true,
      output_quantity: D.new(1)
    }

    changeset = Manufacturing.change_recipe(recipe)

    socket
    |> assign(:recipe, recipe)
    |> assign(:form, to_form(changeset))
    |> assign(:recipe_lines, [new_line_template()])
    |> assign(:materials_totals, materials_totals([]))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    recipe = Manufacturing.get_recipe!(@tenant_id, id)
    changeset = Manufacturing.change_recipe(recipe)

    lines =
      recipe.recipe_items
      |> Enum.sort_by(& &1.line_no)
      |> Enum.map(&line_from_struct/1)

    socket
    |> assign(:recipe, recipe)
    |> assign(:form, to_form(changeset))
    |> assign(:recipe_lines, lines)
    |> assign(:materials_totals, materials_totals(lines))
  end

  @impl true
  def handle_event("filter_active", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_active, status)
     |> load_recipes()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_recipes()}
  end

  def handle_event("add_line", _params, socket) do
    lines = socket.assigns.recipe_lines ++ [new_line_template()]
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("remove_line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    lines = List.delete_at(socket.assigns.recipe_lines, index)
    lines = if lines == [], do: [new_line_template()], else: lines
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("update_lines", %{"lines" => lines_params}, socket) do
    lines = sanitize_line_params(lines_params, socket.assigns.products)
    {:noreply, assign_with_totals(socket, lines)}
  end

  def handle_event("validate", %{"recipe" => recipe_params, "lines" => lines_params}, socket) do
    lines = sanitize_line_params(lines_params, socket.assigns.products)
    recipe = socket.assigns.recipe || %Manufacturing.Recipe{}

    changeset =
      recipe
      |> Manufacturing.change_recipe(normalize_recipe_params(recipe_params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign_with_totals(lines)}
  end

  def handle_event("save", %{"recipe" => recipe_params, "lines" => lines_params}, socket) do
    lines = sanitize_line_params(lines_params, socket.assigns.products)
    attrs = normalize_recipe_params(recipe_params)
    line_attrs = Enum.with_index(lines, 1) |> Enum.map(&line_to_attrs/1)

    save_recipe(socket, socket.assigns.live_action, attrs, line_attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Manufacturing.get_recipe!(@tenant_id, id)
    {:ok, _} = Manufacturing.delete_recipe(recipe)

    {:noreply,
     socket
     |> put_flash(:info, "Рецептата беше изтрита")
     |> load_recipes()}
  end

  defp save_recipe(socket, :new, attrs, line_attrs) do
    case Manufacturing.create_recipe_with_items(attrs, line_attrs) do
      {:ok, _recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Рецептата беше създадена")
         |> assign(:recipe, nil)
         |> assign(:form, nil)
         |> assign(:recipe_lines, [new_line_template()])
         |> assign(:materials_totals, materials_totals([]))
         |> load_recipes()
         |> push_patch(to: ~p"/recipes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_recipe(socket, :edit, attrs, line_attrs) do
    recipe = Manufacturing.get_recipe!(@tenant_id, socket.assigns.recipe.id)

    case Manufacturing.update_recipe_with_items(recipe, attrs, line_attrs) do
      {:ok, _updated_recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Рецептата беше обновена")
         |> load_recipes()
         |> push_patch(to: ~p"/recipes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Грешка при запис: #{inspect(reason)}")}
    end
  end

  defp assign_with_totals(socket, lines) do
    socket
    |> assign(:recipe_lines, lines)
    |> assign(:materials_totals, materials_totals(lines))
  end

  defp load_recipes(socket) do
    opts = build_filter_opts(socket)
    recipes = Manufacturing.list_recipes(@tenant_id, opts)
    assign(socket, :recipes, recipes)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:search, socket.assigns.search_query)
    |> maybe_put(:is_active, status_to_bool(socket.assigns.filter_active))
  end

  defp status_to_bool("active"), do: true
  defp status_to_bool("inactive"), do: false
  defp status_to_bool(_), do: nil

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp sanitize_line_params(lines_params, products) do
    lines_params
    |> Enum.map(fn {index, params} ->
      product_id = parse_integer(params["product_id"])
      product = Enum.find(products, &(&1.id == product_id))
      %{
        index: String.to_integer(index),
        product_id: product_id,
        description: params["description"] || "",
        quantity: params["quantity"] || "1",
        unit: params["unit"] || "бр.",
        wastage_percent: params["wastage_percent"] || "0",
        cost: product && product.cost
      }
    end)
    |> Enum.sort_by(& &1.index)
  end

  defp line_to_attrs({line, index}) do
    %{
      line_no: index,
      product_id: line.product_id,
      description: line.description,
      quantity: to_decimal(line.quantity),
      unit: line.unit,
      wastage_percent: to_decimal(line.wastage_percent),
      cost: line.cost
    }
  end

  defp line_from_struct(line) do
    %{
      index: line.line_no || 1,
      product_id: line.product_id,
      description: line.description,
      quantity: D.to_string(line.quantity || D.new(1)),
      unit: line.unit || "бр.",
      wastage_percent: D.to_string(line.wastage_percent || D.new(0)),
      cost: line.cost
    }
  end

  defp new_line_template do
    %{
      index: System.unique_integer([:positive]),
      product_id: nil,
      description: "",
      quantity: "1",
      unit: "бр.",
      wastage_percent: "0",
      cost: D.new(0)
    }
  end

  defp materials_totals(lines) do
    Enum.reduce(lines, %{total_quantity: D.new(0), total_cost: D.new(0)}, fn line, acc ->
      quantity = to_decimal(line.quantity)
      cost = line.cost || D.new(0)
      total_line_cost = D.mult(quantity, cost)
      %{
        total_quantity: D.add(acc.total_quantity, quantity),
        total_cost: D.add(acc.total_cost, total_line_cost)
      }
    end)
  end

  defp normalize_recipe_params(params) do
    params
    |> Map.put("tenant_id", @tenant_id)
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_decimal(value) when is_binary(value) do
    case value |> String.trim() |> D.parse() do
      {:ok, decimal} -> decimal
      :error -> D.new(0)
    end
  end

  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: D.new(value)
  defp to_decimal(value) when is_float(value), do: D.from_float(value)
  defp to_decimal(nil), do: D.new(0)

  defp status_badge(true),
    do: "inline-flex rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-600"

  defp status_badge(false),
    do: "inline-flex rounded-full bg-gray-200 px-2 py-1 text-xs font-medium text-gray-700"

  defp humanize_bool(true), do: "Активна"
  defp humanize_bool(false), do: "Неактивна"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Производствени рецепти</h1>
          <p class="mt-1 text-sm text-gray-600">Дефиниране на материали и количества за производство на крайни продукти</p>
        </div>
        <.link
          patch={~p"/recipes/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нова рецепта
        </.link>
      </div>

      <div class="grid gap-4 border border-gray-200 bg-white p-4 shadow-sm sm:grid-cols-3 sm:items-end">
        <div>
          <label class="text-xs font-medium text-gray-500">Статус</label>
          <select name="status" phx-change="filter_active" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_active == "all"}>Всички</option>
            <option value="active" selected={@filter_active == "active"}>Активни</option>
            <option value="inactive" selected={@filter_active == "inactive"}>Неактивни</option>
          </select>
        </div>
        <div class="sm:col-span-2">
          <label class="text-xs font-medium text-gray-500">Търсене</label>
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Код или име"
            phx-change="search"
            phx-debounce="300"
            class="mt-1 w-full rounded-md border-gray-300 text-sm"
          />
        </div>
      </div>

      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Код</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Име</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Продукт</th>
              <th class="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Статус</th>
              <th class="px-4 py-2 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">К-во</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for recipe <- @recipes do %>
              <tr>
                <td class="px-4 py-2 text-sm font-medium text-gray-900"><%= recipe.code %></td>
                <td class="px-4 py-2 text-sm text-gray-600"><%= recipe.name %></td>
                <td class="px-4 py-2 text-sm text-gray-500"><%= recipe.output_product && recipe.output_product.name %></td>
                <td class="px-4 py-2 text-sm"><span class={status_badge(recipe.is_active)}><%= humanize_bool(recipe.is_active) %></span></td>
                <td class="px-4 py-2 text-right text-sm text-gray-700"><%= D.to_string(recipe.output_quantity) %> <%= recipe.unit %></td>
                <td class="px-4 py-2 text-right text-sm">
                  <.link patch={~p"/recipes/#{recipe.id}/edit"} class="text-indigo-600 hover:text-indigo-700">Редакция</.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="rounded-lg border border-indigo-100 bg-white p-6 shadow-lg">
          <h2 class="text-lg font-semibold text-gray-900">
            <%= if @live_action == :new, do: "Нова рецепта", else: "Редакция" %>
          </h2>

          <.simple_form
            for={@form}
            id="recipe-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:code]} label="Код" />
              <.input field={@form[:name]} label="Име" />
              <.input field={@form[:output_product_id]} type="select" label="Краен продукт" options={for product <- @products, do: {product.name, product.id}} />
              <.input field={@form[:output_quantity]} label="К-во" type="number" step="0.01" />
              <.input field={@form[:unit]} label="Единица" />
              <.input field={@form[:production_cost]} label="Производствени разходи" type="number" step="0.01" />
              <.input field={@form[:is_active]} type="select" label="Статус" options={[{"Активна", "true"}, {"Неактивна", "false"}]} />
            </div>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-gray-800">Съставки</h3>
                <button type="button" phx-click="add_line" class="inline-flex items-center gap-1 rounded-md bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600 hover:bg-indigo-100">
                  + Добави ред
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left">Продукт</th>
                      <th class="px-3 py-2 text-left">Описание</th>
                      <th class="px-3 py-2 text-right">Кол.</th>
                      <th class="px-3 py-2 text-left">Единица</th>
                      <th class="px-3 py-2 text-right">Отпад %</th>
                      <th class="px-3 py-2 text-right">Цена</th>
                      <th class="px-3 py-2 text-right">Общо</th>
                      <th class="px-3 py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <%= for {line, index} <- Enum.with_index(@recipe_lines) do %>
                      <tr>
                        <td class="px-3 py-2">
                          <select name={"lines[#{index}][product_id]"} class="w-full rounded-md border-gray-300 text-sm" phx-change="update_lines">
                            <option value="">(ръчно)</option>
                            <%= for product <- @products do %>
                              <option value={product.id} selected={line.product_id == product.id}><%= product.name %></option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-3 py-2">
                          <input type="text" name={"lines[#{index}][description]"} value={line.description} class="w-full rounded-md border-gray-300 text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][quantity]"} value={line.quantity} class="w-24 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="text" name={"lines[#{index}][unit]"} value={line.unit} class="w-20 rounded-md border-gray-300 text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2">
                          <input type="number" step="0.01" name={"lines[#{index}][wastage_percent]"} value={line.wastage_percent} class="w-24 rounded-md border-gray-300 text-right text-sm" phx-change="update_lines" />
                        </td>
                        <td class="px-3 py-2 text-right text-sm text-gray-500">
                          <%= D.to_string(line.cost || D.new(0)) %>
                        </td>
                        <td class="px-3 py-2 text-right text-sm font-semibold text-gray-800">
                          <%= D.to_string(D.mult(to_decimal(line.quantity), line.cost || D.new(0))) %>
                        </td>
                        <td class="px-3 py-2 text-right">
                          <button type="button" phx-click="remove_line" phx-value-index={index} class="text-xs text-red-500 hover:text-red-600">Премахни</button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex justify-end text-sm text-gray-600 space-x-4">
                <span>Общо количество материали: <%= D.to_string(@materials_totals.total_quantity) %></span>
                <span class="font-semibold">Обща стойност на материалите: <%= D.to_string(@materials_totals.total_cost) %> лв.</span>
              </div>
            </div>

            <.input field={@form[:description]} type="textarea" label="Описание" rows={3} />
            <.input field={@form[:notes]} type="textarea" label="Бележки" rows={3} />

            <:actions>
              <.button type="submit">Запази</.button>
              <.link patch={~p"/recipes"} class="text-sm text-gray-500 hover:text-gray-700">Отказ</.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>
    """
  end
end
