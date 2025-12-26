defmodule CyberCore.Manufacturing do
  @moduledoc """
  Контекст за производство - технологични карти, производствени поръчки и работни центрове.

  ## Основни функционалности

  ### Работни центрове
  - CRUD операции за работни центрове
  - Изчисляване на капацитет и ефективност

  ### Технологични карти
  - CRUD операции за технологични карти
  - Материали с коефициенти и формули
  - Операции с времена и разходи
  - Автоматично изчисляване на разходи

  ### Производствени поръчки
  - Създаване от технологична карта
  - Стартиране, изпълнение и завършване
  - Проследяване на материали и операции
  - Счетоводни записи

  ## Поддържани стари рецепти
  За обратна съвместимост се поддържат и старите рецепти.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo
  alias CyberCore.Manufacturing.{
    WorkCenter, TechCard, TechCardMaterial, TechCardOperation,
    ProductionOrder, ProductionOrderOperation, ProductionOrderMaterial,
    Recipe, RecipeItem
  }
  alias CyberCore.Inventory
  alias CyberCore.Accounting

  # ============================================================
  # РАБОТНИ ЦЕНТРОВЕ
  # ============================================================

  @doc """
  Списък с работни центрове.
  """
  def list_work_centers(tenant_id, opts \\ []) do
    WorkCenter
    |> where(tenant_id: ^tenant_id)
    |> maybe_filter_active(opts)
    |> maybe_filter_type(opts)
    |> maybe_search(opts, [:code, :name])
    |> order_by([w], w.code)
    |> Repo.all()
  end

  @doc """
  Взима работен център по ID.
  """
  def get_work_center!(tenant_id, id) do
    WorkCenter
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> Repo.one!()
  end

  @doc """
  Създава работен център.
  """
  def create_work_center(attrs) do
    %WorkCenter{}
    |> WorkCenter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира работен център.
  """
  def update_work_center(%WorkCenter{} = work_center, attrs) do
    work_center
    |> WorkCenter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изтрива работен център.
  """
  def delete_work_center(%WorkCenter{} = work_center) do
    Repo.delete(work_center)
  end

  @doc """
  Changeset за работен център.
  """
  def change_work_center(%WorkCenter{} = work_center, attrs \\ %{}) do
    WorkCenter.changeset(work_center, attrs)
  end

  # ============================================================
  # ТЕХНОЛОГИЧНИ КАРТИ
  # ============================================================

  @doc """
  Списък с технологични карти.
  """
  def list_tech_cards(tenant_id, opts \\ []) do
    TechCard
    |> where(tenant_id: ^tenant_id)
    |> maybe_filter_active(opts)
    |> maybe_search(opts, [:code, :name])
    |> order_by([t], [desc: t.updated_at])
    |> preload(:output_product)
    |> Repo.all()
  end

  @doc """
  Взима технологична карта по ID с всички релации.
  """
  def get_tech_card!(tenant_id, id) do
    TechCard
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> Repo.one!()
    |> Repo.preload([
      :output_product,
      materials: [:product],
      operations: [:work_center]
    ])
  end

  @doc """
  Намира активна технологична карта за продукт.
  """
  def find_active_tech_card(tenant_id, product_id) do
    today = Date.utc_today()

    TechCard
    |> where(tenant_id: ^tenant_id, output_product_id: ^product_id, is_active: true)
    |> where([t], is_nil(t.valid_from) or t.valid_from <= ^today)
    |> where([t], is_nil(t.valid_to) or t.valid_to >= ^today)
    |> order_by([t], [desc: t.version])
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      card -> Repo.preload(card, [:materials, :operations])
    end
  end

  @doc """
  Създава технологична карта с материали и операции.
  """
  def create_tech_card_with_details(attrs, materials_attrs, operations_attrs) do
    Repo.transaction(fn ->
      with {:ok, tech_card} <- create_tech_card(attrs),
           {:ok, _materials} <- create_tech_card_materials(tech_card, materials_attrs),
           {:ok, _operations} <- create_tech_card_operations(tech_card, operations_attrs),
           {:ok, tech_card} <- recalculate_tech_card_costs(tech_card) do
        tech_card
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Създава технологична карта.
  """
  def create_tech_card(attrs) do
    %TechCard{}
    |> TechCard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира технологична карта.
  """
  def update_tech_card(%TechCard{} = tech_card, attrs) do
    tech_card
    |> TechCard.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Актуализира технологична карта с материали и операции.
  """
  def update_tech_card_with_details(%TechCard{} = tech_card, attrs, materials_attrs, operations_attrs) do
    Repo.transaction(fn ->
      with {:ok, tech_card} <- update_tech_card(tech_card, attrs),
           :ok <- delete_tech_card_materials(tech_card),
           :ok <- delete_tech_card_operations(tech_card),
           {:ok, _materials} <- create_tech_card_materials(tech_card, materials_attrs),
           {:ok, _operations} <- create_tech_card_operations(tech_card, operations_attrs),
           {:ok, tech_card} <- recalculate_tech_card_costs(tech_card) do
        tech_card
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Изтрива технологична карта.
  """
  def delete_tech_card(%TechCard{} = tech_card) do
    Repo.delete(tech_card)
  end

  @doc """
  Changeset за технологична карта.
  """
  def change_tech_card(%TechCard{} = tech_card, attrs \\ %{}) do
    TechCard.changeset(tech_card, attrs)
  end

  @doc """
  Преизчислява разходите на технологична карта.
  """
  def recalculate_tech_card_costs(%TechCard{} = tech_card) do
    tech_card = Repo.preload(tech_card, [:materials, :operations], force: true)

    output_qty = tech_card.output_quantity

    # Изчисляване на разходи за материали
    material_cost = Enum.reduce(tech_card.materials, Decimal.new(0), fn m, acc ->
      cost = TechCardMaterial.calculate_cost(m, output_qty)
      Decimal.add(acc, cost)
    end)

    # Изчисляване на разходи за операции
    {labor_cost, machine_cost} = Enum.reduce(tech_card.operations, {Decimal.new(0), Decimal.new(0)}, fn op, {labor, machine} ->
      costs = TechCardOperation.calculate_costs(op, output_qty)
      {Decimal.add(labor, costs.labor_cost), Decimal.add(machine, costs.machine_cost)}
    end)

    # Общи преки разходи
    direct_costs = Decimal.add(material_cost, labor_cost) |> Decimal.add(machine_cost)

    # Overhead
    overhead_cost = Decimal.mult(direct_costs, Decimal.div(tech_card.overhead_percent, Decimal.new(100)))

    # Общо
    total_cost = Decimal.add(direct_costs, overhead_cost)

    update_tech_card(tech_card, %{
      material_cost: material_cost,
      labor_cost: labor_cost,
      machine_cost: machine_cost,
      overhead_cost: overhead_cost,
      total_cost: total_cost
    })
  end

  # Материали
  defp create_tech_card_materials(_tech_card, []), do: {:ok, []}
  defp create_tech_card_materials(tech_card, materials_attrs) do
    results = Enum.map(materials_attrs, fn attrs ->
      attrs = Map.merge(attrs, %{
        tenant_id: tech_card.tenant_id,
        tech_card_id: tech_card.id
      })

      %TechCardMaterial{}
      |> TechCardMaterial.changeset(attrs)
      |> Repo.insert()
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, m} -> m end)}
    else
      error = Enum.find(results, &match?({:error, _}, &1))
      error
    end
  end

  defp delete_tech_card_materials(tech_card) do
    TechCardMaterial
    |> where(tech_card_id: ^tech_card.id)
    |> Repo.delete_all()
    :ok
  end

  # Операции
  defp create_tech_card_operations(_tech_card, []), do: {:ok, []}
  defp create_tech_card_operations(tech_card, operations_attrs) do
    results = Enum.map(operations_attrs, fn attrs ->
      attrs = Map.merge(attrs, %{
        tenant_id: tech_card.tenant_id,
        tech_card_id: tech_card.id
      })

      %TechCardOperation{}
      |> TechCardOperation.changeset(attrs)
      |> Repo.insert()
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, op} -> op end)}
    else
      error = Enum.find(results, &match?({:error, _}, &1))
      error
    end
  end

  defp delete_tech_card_operations(tech_card) do
    TechCardOperation
    |> where(tech_card_id: ^tech_card.id)
    |> Repo.delete_all()
    :ok
  end

  # ============================================================
  # ПРОИЗВОДСТВЕНИ ПОРЪЧКИ
  # ============================================================

  @doc """
  Списък с производствени поръчки.
  """
  def list_production_orders(tenant_id, opts \\ []) do
    ProductionOrder
    |> where(tenant_id: ^tenant_id)
    |> maybe_filter_status(opts)
    |> maybe_search(opts, [:order_number, :batch_number])
    |> order_by([p], [desc: p.updated_at])
    |> preload([:output_product, :tech_card, :warehouse])
    |> Repo.all()
  end

  @doc """
  Взима производствена поръчка по ID.
  """
  def get_production_order!(tenant_id, id) do
    ProductionOrder
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> Repo.one!()
    |> Repo.preload([
      :output_product, :tech_card, :warehouse, :recipe,
      operations: [:work_center, :operator],
      materials: [:product]
    ])
  end

  @doc """
  Създава производствена поръчка от технологична карта.
  """
  def create_production_order_from_tech_card(tech_card_id, attrs) do
    Repo.transaction(fn ->
      with tech_card <- get_tech_card!(attrs.tenant_id, tech_card_id),
           {:ok, order} <- do_create_production_order(tech_card, attrs),
           {:ok, _} <- create_order_materials_from_tech_card(order, tech_card),
           {:ok, _} <- create_order_operations_from_tech_card(order, tech_card),
           {:ok, order} <- calculate_estimated_costs(order) do
        order
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp do_create_production_order(tech_card, attrs) do
    attrs = Map.merge(attrs, %{
      tech_card_id: tech_card.id,
      output_product_id: tech_card.output_product_id,
      unit: tech_card.output_unit
    })

    %ProductionOrder{}
    |> ProductionOrder.changeset(attrs)
    |> Repo.insert()
  end

  defp create_order_materials_from_tech_card(order, tech_card) do
    tech_card = Repo.preload(tech_card, [materials: :product])

    results = Enum.map(tech_card.materials, fn material ->
      planned_qty = TechCardMaterial.calculate_quantity(material, order.quantity_to_produce)

      attrs = %{
        tenant_id: order.tenant_id,
        production_order_id: order.id,
        tech_card_material_id: material.id,
        product_id: material.product_id,
        line_no: material.line_no,
        description: material.description || material.product.name,
        planned_quantity: planned_qty,
        unit: material.unit,
        unit_cost: material.unit_cost
      }

      %ProductionOrderMaterial{}
      |> ProductionOrderMaterial.changeset(attrs)
      |> Repo.insert()
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, m} -> m end)}
    else
      {:error, "Грешка при създаване на материали"}
    end
  end

  defp create_order_operations_from_tech_card(order, tech_card) do
    tech_card = Repo.preload(tech_card, :operations)

    results = Enum.map(tech_card.operations, fn op ->
      times = TechCardOperation.calculate_costs(op, order.quantity_to_produce)

      attrs = %{
        tenant_id: order.tenant_id,
        production_order_id: order.id,
        tech_card_operation_id: op.id,
        work_center_id: op.work_center_id,
        sequence_no: op.sequence_no,
        name: op.name,
        description: op.description,
        planned_setup_time: op.setup_time,
        planned_run_time: times.time_minutes,
        labor_rate_per_hour: op.labor_rate_per_hour,
        machine_rate_per_hour: op.machine_rate_per_hour
      }

      %ProductionOrderOperation{}
      |> ProductionOrderOperation.changeset(attrs)
      |> Repo.insert()
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, op} -> op end)}
    else
      {:error, "Грешка при създаване на операции"}
    end
  end

  defp calculate_estimated_costs(order) do
    order = Repo.preload(order, [:materials, :operations], force: true)

    # Материални разходи
    material_cost = Enum.reduce(order.materials, Decimal.new(0), fn m, acc ->
      cost = Decimal.mult(m.planned_quantity, m.unit_cost)
      Decimal.add(acc, cost)
    end)

    # Разходи за труд и машини (от планирани времена)
    {labor_cost, machine_cost} = Enum.reduce(order.operations, {Decimal.new(0), Decimal.new(0)}, fn op, {labor, machine} ->
      total_time = Decimal.add(op.planned_setup_time, op.planned_run_time)
      hours = Decimal.div(total_time, Decimal.new(60))

      labor_rate = op.labor_rate_per_hour || Decimal.new(0)
      machine_rate = op.machine_rate_per_hour || Decimal.new(0)

      {Decimal.add(labor, Decimal.mult(hours, labor_rate)),
       Decimal.add(machine, Decimal.mult(hours, machine_rate))}
    end)

    total = Decimal.add(material_cost, labor_cost) |> Decimal.add(machine_cost)

    update_production_order(order, %{
      estimated_material_cost: material_cost,
      estimated_labor_cost: labor_cost,
      estimated_machine_cost: machine_cost,
      estimated_total_cost: total
    })
  end

  @doc """
  Създава производствена поръчка.
  """
  def create_production_order(attrs) do
    %ProductionOrder{}
    |> ProductionOrder.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира производствена поръчка.
  """
  def update_production_order(%ProductionOrder{} = order, attrs) do
    order
    |> ProductionOrder.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изтрива производствена поръчка.
  """
  def delete_production_order(%ProductionOrder{} = order) do
    Repo.delete(order)
  end

  @doc """
  Changeset за производствена поръчка.
  """
  def change_production_order(%ProductionOrder{} = order, attrs \\ %{}) do
    ProductionOrder.changeset(order, attrs)
  end

  # ============================================================
  # ПРОИЗВОДСТВЕНИ ОПЕРАЦИИ
  # ============================================================

  @doc """
  Стартира производствена поръчка.
  """
  def start_production_order(%ProductionOrder{} = order) do
    Repo.transaction(fn ->
      with :ok <- validate_order_can_start(order),
           :ok <- check_material_availability(order),
           {:ok, order} <- do_start_order(order),
           :ok <- issue_materials(order) do
        Repo.preload(order, [:materials, :operations], force: true)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp validate_order_can_start(%{status: status}) when status in ["draft", "planned"], do: :ok
  defp validate_order_can_start(_), do: {:error, "Поръчката не може да бъде стартирана"}

  defp check_material_availability(order) do
    order = Repo.preload(order, [materials: :product])

    errors = Enum.reduce(order.materials, [], fn material, acc ->
      stock = Inventory.get_stock_level(order.tenant_id, material.product_id, order.warehouse_id)
      available = (stock && stock.quantity_on_hand) || Decimal.new(0)

      if Decimal.lt?(available, material.planned_quantity) do
        ["Недостатъчна наличност за #{material.product.name}: има #{available}, нужно #{material.planned_quantity}" | acc]
      else
        acc
      end
    end)

    if errors == [], do: :ok, else: {:error, Enum.join(errors, "; ")}
  end

  defp do_start_order(order) do
    order
    |> ProductionOrder.start_changeset()
    |> Repo.update()
  end

  defp issue_materials(order) do
    order = Repo.preload(order, [materials: [product: [:account, :expense_account]]])

    Enum.each(order.materials, fn material ->
      product = material.product
      cost = Decimal.mult(material.planned_quantity, material.unit_cost)

      # Създаване на складово движение
      Inventory.create_stock_movement(%{
        tenant_id: order.tenant_id,
        warehouse_id: order.warehouse_id,
        product_id: material.product_id,
        movement_type: "production_issue",
        quantity: material.planned_quantity,
        reference_type: "production_order",
        reference_id: order.id,
        movement_date: Date.utc_today()
      })

      # Счетоводен запис за изписване на материал
      # Дт 601 (разход за материали) / Кт 302 (материали)
      if product.expense_account_id && product.account_id do
        entry_attrs = %{
          tenant_id: order.tenant_id,
          document_date: Date.utc_today(),
          description: "Изписване на материал #{product.name} за поръчка #{order.order_number}",
          source_document_id: order.id,
          source_document_type: "ProductionOrder"
        }

        lines = [
          %{
            account_id: product.expense_account_id,
            debit_amount: cost,
            credit_amount: Decimal.new(0),
            description: "Разход за материал #{product.name}"
          },
          %{
            account_id: product.account_id,
            debit_amount: Decimal.new(0),
            credit_amount: cost,
            description: "Изписване на материал #{product.name}"
          }
        ]

        Accounting.create_journal_entry_with_lines(entry_attrs, lines)
      end

      # Актуализиране на статуса на материала
      material
      |> ProductionOrderMaterial.issue_changeset(material.planned_quantity)
      |> Repo.update()
    end)

    :ok
  end

  @doc """
  Стартира операция.
  """
  def start_operation(%ProductionOrderOperation{} = operation, operator_id \\ nil) do
    operation
    |> ProductionOrderOperation.start_changeset(operator_id)
    |> Repo.update()
  end

  @doc """
  Завършва операция.
  """
  def complete_operation(%ProductionOrderOperation{} = operation, attrs \\ %{}) do
    operation
    |> ProductionOrderOperation.complete_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Завършва производствена поръчка.

  Създава счетоводен запис:
  - Дт product.account_id (303 готова продукция)
  - Кт product.expense_account_id (611 производствени разходи)
  """
  def complete_production_order(%ProductionOrder{} = order, quantity_produced, user_id) do
    Repo.transaction(fn ->
      with {:ok, order} <- do_complete_order(order, quantity_produced),
           {:ok, _} <- receive_finished_goods(order),
           {:ok, order} <- calculate_actual_costs(order),
           {:ok, _} <- create_completion_journal_entry(order, user_id) do
        Repo.preload(order, [:materials, :operations], force: true)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Завършва производствена поръчка (стар API за съвместимост).
  """
  def complete_production_order(%ProductionOrder{} = order, quantity_produced, user_id, _accounting_settings) do
    complete_production_order(order, quantity_produced, user_id)
  end

  defp do_complete_order(order, quantity_produced) do
    order
    |> ProductionOrder.complete_changeset(quantity_produced)
    |> Repo.update()
  end

  defp receive_finished_goods(order) do
    Inventory.create_stock_movement(%{
      tenant_id: order.tenant_id,
      warehouse_id: order.warehouse_id,
      product_id: order.output_product_id,
      movement_type: "production_receipt",
      quantity: order.quantity_produced,
      reference_type: "production_order",
      reference_id: order.id,
      movement_date: Date.utc_today()
    })
  end

  defp calculate_actual_costs(order) do
    order = Repo.preload(order, [:materials, :operations], force: true)

    # Материални разходи
    material_cost = Enum.reduce(order.materials, Decimal.new(0), fn m, acc ->
      Decimal.add(acc, m.total_cost)
    end)

    # Разходи за труд и машини
    {labor_cost, machine_cost} = Enum.reduce(order.operations, {Decimal.new(0), Decimal.new(0)}, fn op, {labor, machine} ->
      {Decimal.add(labor, op.labor_cost), Decimal.add(machine, op.machine_cost)}
    end)

    total = Decimal.add(material_cost, labor_cost) |> Decimal.add(machine_cost)

    update_production_order(order, %{
      actual_material_cost: material_cost,
      actual_labor_cost: labor_cost,
      actual_machine_cost: machine_cost,
      actual_total_cost: total
    })
  end

  defp create_completion_journal_entry(order, user_id) do
    # Зареждаме продукта със сметките
    order = Repo.preload(order, [output_product: [:account, :expense_account]])
    product = order.output_product

    # Проверка дали продуктът има зададени сметки
    unless product.account_id && product.expense_account_id do
      {:error, "Продуктът #{product.name} няма зададени счетоводни сметки (инвентарна и разходна)"}
    else
      entry_attrs = %{
        tenant_id: order.tenant_id,
        document_date: order.completion_date,
        description: "Заприходяване на готова продукция #{product.name} от поръчка #{order.order_number}",
        created_by_id: user_id,
        source_document_id: order.id,
        source_document_type: "ProductionOrder"
      }

      # Дт 303 (готова продукция) / Кт 611 (производствени разходи)
      lines = [
        %{
          account_id: product.account_id,
          debit_amount: order.actual_total_cost,
          credit_amount: Decimal.new(0),
          description: "Заприходяване на #{product.name}"
        },
        %{
          account_id: product.expense_account_id,
          debit_amount: Decimal.new(0),
          credit_amount: order.actual_total_cost,
          description: "Приключване на производствени разходи за #{product.name}"
        }
      ]

      Accounting.create_journal_entry_with_lines(entry_attrs, lines)
    end
  end

  @doc """
  Отменя производствена поръчка.
  """
  def cancel_production_order(%ProductionOrder{} = order, reason \\ nil) do
    order
    |> ProductionOrder.cancel_changeset(reason)
    |> Repo.update()
  end

  # ============================================================
  # СТАРИ РЕЦЕПТИ (за съвместимост)
  # ============================================================

  def list_recipes(tenant_id, opts \\ []) do
    Recipe
    |> where(tenant_id: ^tenant_id)
    |> maybe_filter_active(opts)
    |> maybe_search(opts, [:code, :name])
    |> Repo.all()
  end

  def get_recipe!(tenant_id, id) do
    Recipe
    |> where(tenant_id: ^tenant_id, id: ^id)
    |> Repo.one!()
    |> Repo.preload([:recipe_items, :output_product])
  end

  def create_recipe_with_items(attrs, item_attrs) do
    Repo.transaction(fn ->
      with {:ok, recipe} <- %Recipe{} |> Recipe.changeset(attrs) |> Repo.insert(),
           {:ok, _items} <- create_recipe_items(recipe, item_attrs) do
        recipe
      else
        e -> Repo.rollback(e)
      end
    end)
  end

  def update_recipe_with_items(recipe, attrs, item_attrs) do
    Repo.transaction(fn ->
      with {:ok, updated_recipe} <- recipe |> Recipe.changeset(attrs) |> Repo.update() do
        :ok = delete_recipe_items(recipe)
        {:ok, _items} = create_recipe_items(updated_recipe, item_attrs)
        Repo.preload(updated_recipe, :recipe_items, force: true)
      else
        e -> Repo.rollback(e)
      end
    end)
  end

  def delete_recipe(recipe), do: Repo.delete(recipe)

  def change_recipe(recipe, attrs \\ %{}), do: Recipe.changeset(recipe, attrs)

  defp create_recipe_items(_recipe, []), do: {:ok, []}
  defp create_recipe_items(recipe, item_attrs) do
    results = Enum.map(item_attrs, fn attrs ->
      attrs =
        attrs
        |> Map.put(:recipe_id, recipe.id)
        |> Map.put(:tenant_id, recipe.tenant_id)

      %RecipeItem{}
      |> RecipeItem.changeset(attrs)
      |> Repo.insert()
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, item} -> item end)}
    else
      {:error, Enum.find(results, &match?({:error, _}, &1))}
    end
  end

  defp delete_recipe_items(recipe) do
    recipe
    |> Ecto.assoc(:recipe_items)
    |> Repo.delete_all()
    :ok
  end

  # ============================================================
  # ПОМОЩНИ ФУНКЦИИ
  # ============================================================

  defp maybe_filter_active(query, opts) do
    case Keyword.get(opts, :is_active) do
      nil -> query
      val -> where(query, [q], q.is_active == ^val)
    end
  end

  defp maybe_filter_type(query, opts) do
    case Keyword.get(opts, :center_type) do
      nil -> query
      val -> where(query, [q], q.center_type == ^val)
    end
  end

  defp maybe_filter_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil -> query
      val -> where(query, [q], q.status == ^val)
    end
  end

  defp maybe_search(query, opts, fields) do
    case Keyword.get(opts, :search) do
      nil -> query
      "" -> query
      term ->
        pattern = "%#{term}%"
        Enum.reduce(fields, query, fn field, q ->
          or_where(q, [r], ilike(field(r, ^field), ^pattern))
        end)
    end
  end

  # ============================================================
  # СТАТИСТИКИ И ОТЧЕТИ
  # ============================================================

  @doc """
  Статистика за производството.
  """
  def production_stats(tenant_id, date_from \\ nil, date_to \\ nil) do
    base_query = ProductionOrder |> where(tenant_id: ^tenant_id)

    base_query = if date_from do
      where(base_query, [p], p.planned_date >= ^date_from)
    else
      base_query
    end

    base_query = if date_to do
      where(base_query, [p], p.planned_date <= ^date_to)
    else
      base_query
    end

    orders = Repo.all(base_query)

    %{
      total_orders: length(orders),
      by_status: Enum.group_by(orders, & &1.status) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new(),
      completed: Enum.count(orders, & &1.status == "completed"),
      in_progress: Enum.count(orders, & &1.status == "in_progress"),
      planned: Enum.count(orders, & &1.status == "planned"),
      total_estimated_cost: Enum.reduce(orders, Decimal.new(0), fn o, acc ->
        Decimal.add(acc, o.estimated_total_cost || Decimal.new(0))
      end),
      total_actual_cost: Enum.reduce(orders, Decimal.new(0), fn o, acc ->
        Decimal.add(acc, o.actual_total_cost || Decimal.new(0))
      end)
    }
  end
end
