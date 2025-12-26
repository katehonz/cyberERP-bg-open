defmodule CyberWeb.TechCardLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Manufacturing
  alias CyberCore.Manufacturing.{TechCard}
  alias CyberCore.Inventory
  alias Decimal, as: D

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    products = Inventory.list_products(@tenant_id)
    work_centers = Manufacturing.list_work_centers(@tenant_id, is_active: true)

    {:ok,
     socket
     |> assign(:page_title, "Технологични карти")
     |> assign(:tech_cards, [])
     |> assign(:tech_card, nil)
     |> assign(:form, nil)
     |> assign(:materials, [new_material_template()])
     |> assign(:operations, [new_operation_template()])
     |> assign(:totals, calculate_totals([], []))
     |> assign(:filter_active, "all")
     |> assign(:search_query, "")
     |> assign(:products, products)
     |> assign(:work_centers, work_centers)
     |> assign(:show_formula_help, false)
     |> load_tech_cards()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:tech_card, nil)
    |> assign(:form, nil)
    |> assign(:materials, [new_material_template()])
    |> assign(:operations, [new_operation_template()])
    |> assign(:totals, calculate_totals([], []))
  end

  defp apply_action(socket, :new, _params) do
    tech_card = %TechCard{
      code: "TC-" <> Integer.to_string(System.unique_integer([:positive])),
      is_active: true,
      output_quantity: D.new(1),
      output_unit: "бр.",
      version: "1.0",
      overhead_percent: D.new(0)
    }

    changeset = Manufacturing.change_tech_card(tech_card)

    socket
    |> assign(:tech_card, tech_card)
    |> assign(:form, to_form(changeset))
    |> assign(:materials, [new_material_template()])
    |> assign(:operations, [new_operation_template()])
    |> assign(:totals, calculate_totals([], []))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    tech_card = Manufacturing.get_tech_card!(@tenant_id, id)
    changeset = Manufacturing.change_tech_card(tech_card)

    materials = tech_card.materials
    |> Enum.sort_by(& &1.line_no)
    |> Enum.map(&material_from_struct/1)

    operations = tech_card.operations
    |> Enum.sort_by(& &1.sequence_no)
    |> Enum.map(&operation_from_struct/1)

    materials = if materials == [], do: [new_material_template()], else: materials
    operations = if operations == [], do: [new_operation_template()], else: operations

    socket
    |> assign(:tech_card, tech_card)
    |> assign(:form, to_form(changeset))
    |> assign(:materials, materials)
    |> assign(:operations, operations)
    |> assign(:totals, calculate_totals(materials, operations))
  end

  @impl true
  def handle_event("filter_active", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_active, status)
     |> load_tech_cards()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_tech_cards()}
  end

  def handle_event("toggle_formula_help", _, socket) do
    {:noreply, assign(socket, :show_formula_help, !socket.assigns.show_formula_help)}
  end

  # Материали
  def handle_event("add_material", _params, socket) do
    materials = socket.assigns.materials ++ [new_material_template()]
    {:noreply, assign_with_totals(socket, materials, socket.assigns.operations)}
  end

  def handle_event("remove_material", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    materials = List.delete_at(socket.assigns.materials, index)
    materials = if materials == [], do: [new_material_template()], else: materials
    {:noreply, assign_with_totals(socket, materials, socket.assigns.operations)}
  end

  def handle_event("update_materials", %{"materials" => materials_params}, socket) do
    materials = sanitize_material_params(materials_params, socket.assigns.products)
    {:noreply, assign_with_totals(socket, materials, socket.assigns.operations)}
  end

  # Операции
  def handle_event("add_operation", _params, socket) do
    operations = socket.assigns.operations ++ [new_operation_template()]
    {:noreply, assign_with_totals(socket, socket.assigns.materials, operations)}
  end

  def handle_event("remove_operation", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    operations = List.delete_at(socket.assigns.operations, index)
    operations = if operations == [], do: [new_operation_template()], else: operations
    {:noreply, assign_with_totals(socket, socket.assigns.materials, operations)}
  end

  def handle_event("update_operations", %{"operations" => operations_params}, socket) do
    operations = sanitize_operation_params(operations_params, socket.assigns.work_centers)
    {:noreply, assign_with_totals(socket, socket.assigns.materials, operations)}
  end

  def handle_event("validate", params, socket) do
    materials = case params["materials"] do
      nil -> socket.assigns.materials
      m -> sanitize_material_params(m, socket.assigns.products)
    end

    operations = case params["operations"] do
      nil -> socket.assigns.operations
      o -> sanitize_operation_params(o, socket.assigns.work_centers)
    end

    tech_card = socket.assigns.tech_card || %TechCard{}
    changeset =
      tech_card
      |> Manufacturing.change_tech_card(normalize_params(params["tech_card"] || %{}))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign_with_totals(materials, operations)}
  end

  def handle_event("save", params, socket) do
    materials = case params["materials"] do
      nil -> socket.assigns.materials
      m -> sanitize_material_params(m, socket.assigns.products)
    end

    operations = case params["operations"] do
      nil -> socket.assigns.operations
      o -> sanitize_operation_params(o, socket.assigns.work_centers)
    end

    attrs = normalize_params(params["tech_card"] || %{})
    material_attrs = materials |> Enum.with_index(1) |> Enum.map(&material_to_attrs/1)
    operation_attrs = operations |> Enum.with_index(1) |> Enum.map(&operation_to_attrs/1)

    save_tech_card(socket, socket.assigns.live_action, attrs, material_attrs, operation_attrs)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    tech_card = Manufacturing.get_tech_card!(@tenant_id, id)
    {:ok, _} = Manufacturing.delete_tech_card(tech_card)

    {:noreply,
     socket
     |> put_flash(:info, "Технологичната карта беше изтрита")
     |> load_tech_cards()}
  end

  defp save_tech_card(socket, :new, attrs, material_attrs, operation_attrs) do
    case Manufacturing.create_tech_card_with_details(attrs, material_attrs, operation_attrs) do
      {:ok, _tech_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Технологичната карта беше създадена")
         |> reset_form()
         |> load_tech_cards()
         |> push_patch(to: ~p"/tech-cards")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
    end
  end

  defp save_tech_card(socket, :edit, attrs, material_attrs, operation_attrs) do
    tech_card = Manufacturing.get_tech_card!(@tenant_id, socket.assigns.tech_card.id)

    case Manufacturing.update_tech_card_with_details(tech_card, attrs, material_attrs, operation_attrs) do
      {:ok, _tech_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Технологичната карта беше обновена")
         |> load_tech_cards()
         |> push_patch(to: ~p"/tech-cards")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка: #{inspect(reason)}")}
    end
  end

  defp reset_form(socket) do
    socket
    |> assign(:tech_card, nil)
    |> assign(:form, nil)
    |> assign(:materials, [new_material_template()])
    |> assign(:operations, [new_operation_template()])
    |> assign(:totals, calculate_totals([], []))
  end

  defp assign_with_totals(socket, materials, operations) do
    socket
    |> assign(:materials, materials)
    |> assign(:operations, operations)
    |> assign(:totals, calculate_totals(materials, operations))
  end

  defp load_tech_cards(socket) do
    opts = build_filter_opts(socket)
    tech_cards = Manufacturing.list_tech_cards(@tenant_id, opts)
    assign(socket, :tech_cards, tech_cards)
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

  # ===== МАТЕРИАЛИ =====

  defp new_material_template do
    %{
      index: System.unique_integer([:positive]),
      product_id: nil,
      description: "",
      quantity: "1",
      unit: "бр.",
      coefficient: "1.0",
      wastage_percent: "0",
      quantity_formula: "",
      unit_cost: D.new(0),
      is_fixed: false
    }
  end

  defp material_from_struct(m) do
    %{
      index: m.line_no || 1,
      product_id: m.product_id,
      description: m.description || "",
      quantity: D.to_string(m.quantity || D.new(1)),
      unit: m.unit || "бр.",
      coefficient: D.to_string(m.coefficient || D.new("1.0")),
      wastage_percent: D.to_string(m.wastage_percent || D.new(0)),
      quantity_formula: m.quantity_formula || "",
      unit_cost: m.unit_cost || D.new(0),
      is_fixed: m.is_fixed || false
    }
  end

  defp sanitize_material_params(params, products) do
    params
    |> Enum.map(fn {index, p} ->
      product_id = parse_integer(p["product_id"])
      product = Enum.find(products, &(&1.id == product_id))
      %{
        index: String.to_integer(index),
        product_id: product_id,
        description: p["description"] || "",
        quantity: p["quantity"] || "1",
        unit: p["unit"] || "бр.",
        coefficient: p["coefficient"] || "1.0",
        wastage_percent: p["wastage_percent"] || "0",
        quantity_formula: p["quantity_formula"] || "",
        unit_cost: (product && product.cost) || D.new(0),
        is_fixed: p["is_fixed"] == "true"
      }
    end)
    |> Enum.sort_by(& &1.index)
  end

  defp material_to_attrs({m, index}) do
    %{
      line_no: index * 10,
      product_id: m.product_id,
      description: m.description,
      quantity: to_decimal(m.quantity),
      unit: m.unit,
      coefficient: to_decimal(m.coefficient),
      wastage_percent: to_decimal(m.wastage_percent),
      quantity_formula: if(m.quantity_formula == "", do: nil, else: m.quantity_formula),
      unit_cost: m.unit_cost,
      is_fixed: m.is_fixed
    }
  end

  # ===== ОПЕРАЦИИ =====

  defp new_operation_template do
    %{
      index: System.unique_integer([:positive]),
      work_center_id: nil,
      operation_code: "",
      name: "",
      description: "",
      setup_time: "0",
      run_time_per_unit: "0",
      wait_time: "0",
      move_time: "0",
      time_coefficient: "1.0",
      efficiency_coefficient: "1.0",
      time_formula: "",
      labor_rate_per_hour: "20",
      machine_rate_per_hour: "15",
      requires_qc: false
    }
  end

  defp operation_from_struct(op) do
    %{
      index: op.sequence_no || 1,
      work_center_id: op.work_center_id,
      operation_code: op.operation_code || "",
      name: op.name || "",
      description: op.description || "",
      setup_time: D.to_string(op.setup_time || D.new(0)),
      run_time_per_unit: D.to_string(op.run_time_per_unit || D.new(0)),
      wait_time: D.to_string(op.wait_time || D.new(0)),
      move_time: D.to_string(op.move_time || D.new(0)),
      time_coefficient: D.to_string(op.time_coefficient || D.new("1.0")),
      efficiency_coefficient: D.to_string(op.efficiency_coefficient || D.new("1.0")),
      time_formula: op.time_formula || "",
      labor_rate_per_hour: D.to_string(op.labor_rate_per_hour || D.new(20)),
      machine_rate_per_hour: D.to_string(op.machine_rate_per_hour || D.new(15)),
      requires_qc: op.requires_qc || false
    }
  end

  defp sanitize_operation_params(params, work_centers) do
    params
    |> Enum.map(fn {index, p} ->
      wc_id = parse_integer(p["work_center_id"])
      wc = Enum.find(work_centers, &(&1.id == wc_id))
      %{
        index: String.to_integer(index),
        work_center_id: wc_id,
        operation_code: p["operation_code"] || "",
        name: p["name"] || "",
        description: p["description"] || "",
        setup_time: p["setup_time"] || "0",
        run_time_per_unit: p["run_time_per_unit"] || "0",
        wait_time: p["wait_time"] || "0",
        move_time: p["move_time"] || "0",
        time_coefficient: p["time_coefficient"] || "1.0",
        efficiency_coefficient: p["efficiency_coefficient"] || "1.0",
        time_formula: p["time_formula"] || "",
        labor_rate_per_hour: (wc && D.to_string(wc.hourly_rate)) || p["labor_rate_per_hour"] || "20",
        machine_rate_per_hour: p["machine_rate_per_hour"] || "15",
        requires_qc: p["requires_qc"] == "true"
      }
    end)
    |> Enum.sort_by(& &1.index)
  end

  defp operation_to_attrs({op, index}) do
    %{
      sequence_no: index * 10,
      work_center_id: op.work_center_id,
      operation_code: if(op.operation_code == "", do: nil, else: op.operation_code),
      name: op.name,
      description: if(op.description == "", do: nil, else: op.description),
      setup_time: to_decimal(op.setup_time),
      run_time_per_unit: to_decimal(op.run_time_per_unit),
      wait_time: to_decimal(op.wait_time),
      move_time: to_decimal(op.move_time),
      time_coefficient: to_decimal(op.time_coefficient),
      efficiency_coefficient: to_decimal(op.efficiency_coefficient),
      time_formula: if(op.time_formula == "", do: nil, else: op.time_formula),
      labor_rate_per_hour: to_decimal(op.labor_rate_per_hour),
      machine_rate_per_hour: to_decimal(op.machine_rate_per_hour),
      requires_qc: op.requires_qc
    }
  end

  # ===== ИЗЧИСЛЕНИЯ =====

  defp calculate_totals(materials, operations) do
    material_cost = Enum.reduce(materials, D.new(0), fn m, acc ->
      qty = to_decimal(m.quantity)
      coef = to_decimal(m.coefficient)
      waste = to_decimal(m.wastage_percent)
      cost = m.unit_cost || D.new(0)

      effective_qty = D.mult(qty, coef)
      |> D.mult(D.add(D.new(1), D.div(waste, D.new(100))))

      D.add(acc, D.mult(effective_qty, cost))
    end)

    {labor_cost, machine_cost, total_time} = Enum.reduce(operations, {D.new(0), D.new(0), D.new(0)}, fn op, {labor, machine, time} ->
      setup = to_decimal(op.setup_time)
      run = to_decimal(op.run_time_per_unit)
      wait = to_decimal(op.wait_time)
      move = to_decimal(op.move_time)
      time_coef = to_decimal(op.time_coefficient)
      eff_coef = to_decimal(op.efficiency_coefficient)
      labor_rate = to_decimal(op.labor_rate_per_hour)
      machine_rate = to_decimal(op.machine_rate_per_hour)

      # Базово време (за 1 единица)
      base_time = D.add(setup, run) |> D.add(wait) |> D.add(move)
      adjusted_time = D.mult(base_time, time_coef) |> D.div(eff_coef)
      hours = D.div(adjusted_time, D.new(60))

      {
        D.add(labor, D.mult(hours, labor_rate)),
        D.add(machine, D.mult(hours, machine_rate)),
        D.add(time, adjusted_time)
      }
    end)

    total_cost = D.add(material_cost, labor_cost) |> D.add(machine_cost)

    %{
      material_cost: material_cost,
      labor_cost: labor_cost,
      machine_cost: machine_cost,
      total_cost: total_cost,
      total_time: total_time
    }
  end

  defp normalize_params(params) do
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

  defp status_badge(true), do: "bg-emerald-100 text-emerald-700"
  defp status_badge(false), do: "bg-gray-200 text-gray-600"

  defp format_time(minutes) do
    m = D.to_float(minutes) |> round()
    hours = div(m, 60)
    mins = rem(m, 60)
    cond do
      hours > 0 and mins > 0 -> "#{hours}ч #{mins}мин"
      hours > 0 -> "#{hours}ч"
      true -> "#{mins}мин"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Технологични карти</h1>
          <p class="mt-1 text-sm text-gray-600">Дефиниране на материали, операции и разходи за производство</p>
        </div>
        <.link
          patch={~p"/tech-cards/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нова технологична карта
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
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Код</th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Име</th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Продукт</th>
              <th class="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wide text-gray-500">Версия</th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Общ разход</th>
              <th class="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wide text-gray-500">Статус</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for tc <- @tech_cards do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm font-medium text-gray-900"><%= tc.code %></td>
                <td class="px-4 py-3 text-sm text-gray-600"><%= tc.name %></td>
                <td class="px-4 py-3 text-sm text-gray-500"><%= tc.output_product && tc.output_product.name %></td>
                <td class="px-4 py-3 text-center text-sm text-gray-500"><%= tc.version %></td>
                <td class="px-4 py-3 text-right text-sm font-medium text-gray-900"><%= D.to_string(tc.total_cost || D.new(0)) %> лв.</td>
                <td class="px-4 py-3 text-center">
                  <span class={"inline-flex rounded-full px-2 py-1 text-xs font-medium #{status_badge(tc.is_active)}"}>
                    <%= if tc.is_active, do: "Активна", else: "Неактивна" %>
                  </span>
                </td>
                <td class="px-4 py-3 text-right text-sm space-x-2">
                  <.link patch={~p"/tech-cards/#{tc.id}/edit"} class="text-indigo-600 hover:text-indigo-700">Редакция</.link>
                  <button type="button" phx-click="delete" phx-value-id={tc.id} data-confirm="Сигурни ли сте?" class="text-red-600 hover:text-red-700">Изтрий</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @tech_cards == [] do %>
          <div class="py-12 text-center text-sm text-gray-500">
            Няма намерени технологични карти
          </div>
        <% end %>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="rounded-lg border border-indigo-100 bg-white p-6 shadow-lg">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">
              <%= if @live_action == :new, do: "Нова технологична карта", else: "Редакция" %>
            </h2>
            <button type="button" phx-click="toggle_formula_help" class="text-sm text-indigo-600 hover:text-indigo-700">
              <%= if @show_formula_help, do: "Скрий помощ за формули", else: "Покажи помощ за формули" %>
            </button>
          </div>

          <%= if @show_formula_help do %>
            <div class="mt-4 rounded-md bg-blue-50 p-4 text-sm">
              <h4 class="font-semibold text-blue-800">Помощ за формули</h4>
              <div class="mt-2 grid gap-4 sm:grid-cols-2">
                <div>
                  <p class="font-medium text-blue-700">Формули за материали:</p>
                  <ul class="mt-1 list-inside list-disc text-blue-600">
                    <li><code>quantity * coefficient</code> - базова</li>
                    <li><code>quantity * (1 + wastage_percent / 100)</code> - с брак</li>
                    <li><code>if(output_quantity > 100, quantity * 0.95, quantity)</code> - с отстъпка</li>
                  </ul>
                </div>
                <div>
                  <p class="font-medium text-blue-700">Формули за време:</p>
                  <ul class="mt-1 list-inside list-disc text-blue-600">
                    <li><code>setup_time + run_time_per_unit * quantity</code></li>
                    <li><code>if(quantity > 1000, setup_time * 0.5, setup_time)</code></li>
                  </ul>
                </div>
              </div>
              <p class="mt-2 text-xs text-blue-500">Поддържани функции: round(), ceil(), floor(), abs(), min(), max(), if()</p>
            </div>
          <% end %>

          <.simple_form
            for={@form}
            id="tech-card-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 sm:grid-cols-3">
              <.input field={@form[:code]} label="Код" />
              <.input field={@form[:name]} label="Име" />
              <.input field={@form[:version]} label="Версия" />
            </div>

            <div class="grid gap-4 sm:grid-cols-4">
              <.input field={@form[:output_product_id]} type="select" label="Краен продукт" options={[{"-- Изберете --", nil}] ++ for(p <- @products, do: {p.name, p.id})} />
              <.input field={@form[:output_quantity]} label="К-во" type="number" step="0.01" />
              <.input field={@form[:output_unit]} label="Единица" />
              <.input field={@form[:is_active]} type="select" label="Статус" options={[{"Активна", "true"}, {"Неактивна", "false"}]} />
            </div>

            <div class="grid gap-4 sm:grid-cols-4">
              <.input field={@form[:valid_from]} type="date" label="Валидна от" />
              <.input field={@form[:valid_to]} type="date" label="Валидна до" />
              <.input field={@form[:overhead_percent]} label="Overhead %" type="number" step="0.1" />
            </div>

            <!-- МАТЕРИАЛИ -->
            <div class="space-y-4">
              <div class="flex items-center justify-between border-b pb-2">
                <h3 class="text-sm font-semibold text-gray-800">Материали (BOM)</h3>
                <button type="button" phx-click="add_material" class="inline-flex items-center gap-1 rounded-md bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600 hover:bg-indigo-100">
                  + Добави материал
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-2 py-2 text-left">Продукт</th>
                      <th class="px-2 py-2 text-right w-20">К-во</th>
                      <th class="px-2 py-2 text-left w-16">Ед.</th>
                      <th class="px-2 py-2 text-right w-20">Коеф.</th>
                      <th class="px-2 py-2 text-right w-20">Брак %</th>
                      <th class="px-2 py-2 text-left">Формула</th>
                      <th class="px-2 py-2 text-right w-20">Цена</th>
                      <th class="px-2 py-2 text-center w-16">Фикс.</th>
                      <th class="px-2 py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <%= for {m, idx} <- Enum.with_index(@materials) do %>
                      <tr>
                        <td class="px-2 py-2">
                          <select name={"materials[#{idx}][product_id]"} class="w-full rounded-md border-gray-300 text-sm" phx-change="update_materials">
                            <option value="">-- Изберете --</option>
                            <%= for p <- @products do %>
                              <option value={p.id} selected={m.product_id == p.id}><%= p.name %></option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.001" name={"materials[#{idx}][quantity]"} value={m.quantity} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="text" name={"materials[#{idx}][unit]"} value={m.unit} class="w-full rounded-md border-gray-300 text-sm" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.001" name={"materials[#{idx}][coefficient]"} value={m.coefficient} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.1" name={"materials[#{idx}][wastage_percent]"} value={m.wastage_percent} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="text" name={"materials[#{idx}][quantity_formula]"} value={m.quantity_formula} placeholder="опционално" class="w-full rounded-md border-gray-300 text-sm text-xs" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2 text-right text-sm text-gray-500">
                          <%= D.to_string(m.unit_cost) %>
                        </td>
                        <td class="px-2 py-2 text-center">
                          <input type="checkbox" name={"materials[#{idx}][is_fixed]"} value="true" checked={m.is_fixed} class="rounded border-gray-300" phx-change="update_materials" />
                        </td>
                        <td class="px-2 py-2 text-right">
                          <button type="button" phx-click="remove_material" phx-value-index={idx} class="text-xs text-red-500 hover:text-red-600">X</button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>

            <!-- ОПЕРАЦИИ -->
            <div class="space-y-4">
              <div class="flex items-center justify-between border-b pb-2">
                <h3 class="text-sm font-semibold text-gray-800">Операции</h3>
                <button type="button" phx-click="add_operation" class="inline-flex items-center gap-1 rounded-md bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600 hover:bg-indigo-100">
                  + Добави операция
                </button>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-2 py-2 text-left">Работен център</th>
                      <th class="px-2 py-2 text-left">Име</th>
                      <th class="px-2 py-2 text-right w-16">Setup</th>
                      <th class="px-2 py-2 text-right w-16">Run/ед</th>
                      <th class="px-2 py-2 text-right w-16">Коеф.</th>
                      <th class="px-2 py-2 text-right w-20">Труд лв/ч</th>
                      <th class="px-2 py-2 text-right w-20">Маш. лв/ч</th>
                      <th class="px-2 py-2 text-center w-12">QC</th>
                      <th class="px-2 py-2"></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <%= for {op, idx} <- Enum.with_index(@operations) do %>
                      <tr>
                        <td class="px-2 py-2">
                          <select name={"operations[#{idx}][work_center_id]"} class="w-full rounded-md border-gray-300 text-sm" phx-change="update_operations">
                            <option value="">-- Изберете --</option>
                            <%= for wc <- @work_centers do %>
                              <option value={wc.id} selected={op.work_center_id == wc.id}><%= wc.name %></option>
                            <% end %>
                          </select>
                        </td>
                        <td class="px-2 py-2">
                          <input type="text" name={"operations[#{idx}][name]"} value={op.name} placeholder="Име на операция" class="w-full rounded-md border-gray-300 text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.1" name={"operations[#{idx}][setup_time]"} value={op.setup_time} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.01" name={"operations[#{idx}][run_time_per_unit]"} value={op.run_time_per_unit} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.01" name={"operations[#{idx}][time_coefficient]"} value={op.time_coefficient} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.01" name={"operations[#{idx}][labor_rate_per_hour]"} value={op.labor_rate_per_hour} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2">
                          <input type="number" step="0.01" name={"operations[#{idx}][machine_rate_per_hour]"} value={op.machine_rate_per_hour} class="w-full rounded-md border-gray-300 text-right text-sm" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2 text-center">
                          <input type="checkbox" name={"operations[#{idx}][requires_qc]"} value="true" checked={op.requires_qc} class="rounded border-gray-300" phx-change="update_operations" />
                        </td>
                        <td class="px-2 py-2 text-right">
                          <button type="button" phx-click="remove_operation" phx-value-index={idx} class="text-xs text-red-500 hover:text-red-600">X</button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>

            <!-- ОБОБЩЕНИЕ НА РАЗХОДИТЕ -->
            <div class="rounded-md bg-gray-50 p-4">
              <h4 class="text-sm font-semibold text-gray-700">Изчислени разходи (за 1 единица)</h4>
              <div class="mt-3 grid grid-cols-2 gap-4 sm:grid-cols-5 text-sm">
                <div>
                  <span class="text-gray-500">Материали:</span>
                  <span class="ml-2 font-medium"><%= D.round(@totals.material_cost, 2) |> D.to_string() %> лв.</span>
                </div>
                <div>
                  <span class="text-gray-500">Труд:</span>
                  <span class="ml-2 font-medium"><%= D.round(@totals.labor_cost, 2) |> D.to_string() %> лв.</span>
                </div>
                <div>
                  <span class="text-gray-500">Машини:</span>
                  <span class="ml-2 font-medium"><%= D.round(@totals.machine_cost, 2) |> D.to_string() %> лв.</span>
                </div>
                <div>
                  <span class="text-gray-500">Време:</span>
                  <span class="ml-2 font-medium"><%= format_time(@totals.total_time) %></span>
                </div>
                <div class="font-semibold text-indigo-600">
                  <span>ОБЩО:</span>
                  <span class="ml-2"><%= D.round(@totals.total_cost, 2) |> D.to_string() %> лв.</span>
                </div>
              </div>
            </div>

            <.input field={@form[:description]} type="textarea" label="Описание" rows={2} />
            <.input field={@form[:notes]} type="textarea" label="Бележки" rows={2} />

            <:actions>
              <.button type="submit">Запази</.button>
              <.link patch={~p"/tech-cards"} class="text-sm text-gray-500 hover:text-gray-700">Отказ</.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>
    """
  end
end
