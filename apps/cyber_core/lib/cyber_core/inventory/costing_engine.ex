defmodule CyberCore.Inventory.CostingEngine do
  @moduledoc """
  Машина за изчисляване на себестойност на материалните запаси.

  Поддържа три метода:
  - `weighted_average` - Средно претеглена цена
  - `fifo` - First In, First Out
  - `lifo` - Last In, First Out

  ## Преизчисляване при ретроактивни документи

  При въвеждане на документ с минала дата, системата автоматично
  преизчислява всички следващи движения за съответния продукт/склад.
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Inventory.{StockMovement, StockCostLayer, StockLevel, Warehouse}
  alias Decimal

  @incoming_types ~w(in surplus production_receipt opening_balance purchase)
  @outgoing_types ~w(out shortage scrapping production_issue sale)

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Обработва движение и изчислява себестойността.

  Връща `{:ok, movement}` с попълнени `computed_unit_cost` и `computed_total_cost`.
  При грешка връща `{:error, reason}`.
  """
  def process_movement(%StockMovement{} = movement) do
    warehouse = Repo.get!(Warehouse, movement.warehouse_id)
    method = warehouse.costing_method || "weighted_average"

    # Проверка дали има движения след тази дата
    needs_recalculation = has_later_movements?(movement)

    result = Repo.transaction(fn ->
      case process_by_method(movement, method) do
        {:ok, updated_movement} ->
          # Ако има по-късни движения, преизчисли ги
          if needs_recalculation do
            recalculate_later_movements(movement, method)
          end
          updated_movement

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)

    result
  end

  @doc """
  Преизчислява всички движения за продукт/склад от дадена дата.
  """
  def recalculate_from_date(tenant_id, product_id, warehouse_id, from_date) do
    warehouse = Repo.get!(Warehouse, warehouse_id)
    method = warehouse.costing_method || "weighted_average"

    Repo.transaction(fn ->
      # Изтриваме слоевете от тази дата нататък
      delete_layers_from_date(tenant_id, product_id, warehouse_id, from_date)

      # Взимаме всички движения от тази дата нататък
      movements = get_movements_from_date(tenant_id, product_id, warehouse_id, from_date)

      # Преизчисляваме всяко движение
      Enum.each(movements, fn movement ->
        case process_by_method(movement, method) do
          {:ok, _} -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      :ok
    end)
  end

  @doc """
  Връща текущата средна цена за продукт в склад.
  """
  def get_average_cost(tenant_id, product_id, warehouse_id) do
    case Repo.get_by(StockLevel,
           tenant_id: tenant_id,
           product_id: product_id,
           warehouse_id: warehouse_id
         ) do
      nil -> Decimal.new(0)
      level -> level.average_cost || Decimal.new(0)
    end
  end

  @doc """
  Връща активните слоеве за продукт в склад.
  """
  def get_active_layers(tenant_id, product_id, warehouse_id) do
    StockCostLayer
    |> where(
      [l],
      l.tenant_id == ^tenant_id and
        l.product_id == ^product_id and
        l.warehouse_id == ^warehouse_id and
        l.status == "active"
    )
    |> order_by([l], asc: l.layer_date, asc: l.id)
    |> Repo.all()
  end

  # ============================================================
  # PRIVATE - METHOD DISPATCH
  # ============================================================

  defp process_by_method(movement, method) do
    cond do
      movement.movement_type in @incoming_types ->
        process_incoming(movement, method)

      movement.movement_type in @outgoing_types ->
        process_outgoing(movement, method)

      movement.movement_type == "transfer" ->
        process_transfer(movement, method)

      true ->
        {:error, "Неизвестен тип движение: #{movement.movement_type}"}
    end
  end

  # ============================================================
  # INCOMING (приемане)
  # ============================================================

  defp process_incoming(movement, method) do
    unit_cost = movement.unit_cost || Decimal.new(0)
    total_cost = Decimal.mult(movement.quantity, unit_cost)

    # За FIFO/LIFO създаваме слой
    if method in ["fifo", "lifo"] do
      create_layer(movement)
    end

    # Актуализираме средната цена
    update_average_cost_on_receipt(movement, unit_cost)

    # Записваме изчислената себестойност
    movement
    |> StockMovement.changeset(%{
      computed_unit_cost: unit_cost,
      computed_total_cost: total_cost
    })
    |> Repo.update()
  end

  defp create_layer(movement) do
    layer = StockCostLayer.from_movement(movement)

    %StockCostLayer{}
    |> StockCostLayer.changeset(Map.from_struct(layer))
    |> Repo.insert!()
  end

  defp update_average_cost_on_receipt(movement, unit_cost) do
    level = get_or_create_stock_level(movement)

    old_qty = level.quantity_on_hand || Decimal.new(0)
    old_total = level.total_value || Decimal.new(0)

    new_qty = Decimal.add(old_qty, movement.quantity)
    new_total = Decimal.add(old_total, Decimal.mult(movement.quantity, unit_cost))

    new_avg =
      if Decimal.gt?(new_qty, Decimal.new(0)) do
        Decimal.div(new_total, new_qty)
      else
        Decimal.new(0)
      end

    level
    |> StockLevel.changeset(%{
      average_cost: new_avg,
      total_value: new_total
    })
    |> Repo.update!()
  end

  # ============================================================
  # OUTGOING (изписване)
  # ============================================================

  defp process_outgoing(movement, method) do
    case method do
      "weighted_average" -> process_outgoing_weighted_average(movement)
      "fifo" -> process_outgoing_fifo(movement)
      "lifo" -> process_outgoing_lifo(movement)
    end
  end

  defp process_outgoing_weighted_average(movement) do
    level = get_or_create_stock_level(movement)
    avg_cost = level.average_cost || Decimal.new(0)
    total_cost = Decimal.mult(movement.quantity, avg_cost)

    # Актуализираме total_value на нивото
    new_total = Decimal.sub(level.total_value || Decimal.new(0), total_cost)

    level
    |> StockLevel.changeset(%{total_value: Decimal.max(new_total, Decimal.new(0))})
    |> Repo.update!()

    # Записваме изчислената себестойност
    movement
    |> StockMovement.changeset(%{
      computed_unit_cost: avg_cost,
      computed_total_cost: total_cost
    })
    |> Repo.update()
  end

  defp process_outgoing_fifo(movement) do
    consume_layers(movement, :asc)
  end

  defp process_outgoing_lifo(movement) do
    consume_layers(movement, :desc)
  end

  defp consume_layers(movement, order) do
    layers = get_active_layers_ordered(movement, order)

    {remaining_qty, total_cost, consumed} =
      consume_from_layers(layers, movement.quantity, Decimal.new(0), [])

    # Проверка за недостиг
    if Decimal.gt?(remaining_qty, Decimal.new(0)) do
      {:error, "Недостатъчна наличност. Липсват #{Decimal.to_string(remaining_qty)} единици."}
    else
      # Актуализираме слоевете
      Enum.each(consumed, fn {layer, consumed_qty} ->
        new_remaining = Decimal.sub(layer.remaining_quantity, consumed_qty)
        status = if Decimal.eq?(new_remaining, Decimal.new(0)), do: "depleted", else: "active"

        layer
        |> StockCostLayer.changeset(%{remaining_quantity: new_remaining, status: status})
        |> Repo.update!()
      end)

      # Средна цена от консумираните слоеве
      avg_cost =
        if Decimal.gt?(movement.quantity, Decimal.new(0)) do
          Decimal.div(total_cost, movement.quantity)
        else
          Decimal.new(0)
        end

      # Актуализираме stock level
      update_stock_level_on_issue(movement, total_cost)

      # Записваме изчислената себестойност
      movement
      |> StockMovement.changeset(%{
        computed_unit_cost: avg_cost,
        computed_total_cost: total_cost
      })
      |> Repo.update()
    end
  end

  defp get_active_layers_ordered(movement, order) do
    order_clause = if order == :asc, do: [asc: :layer_date, asc: :id], else: [desc: :layer_date, desc: :id]

    StockCostLayer
    |> where(
      [l],
      l.tenant_id == ^movement.tenant_id and
        l.product_id == ^movement.product_id and
        l.warehouse_id == ^movement.warehouse_id and
        l.status == "active" and
        l.layer_date <= ^movement.movement_date
    )
    |> order_by(^order_clause)
    |> Repo.all()
  end

  defp consume_from_layers([], remaining_qty, total_cost, consumed) do
    {remaining_qty, total_cost, consumed}
  end

  defp consume_from_layers([layer | rest], remaining_qty, total_cost, consumed) do
    if Decimal.lte?(remaining_qty, Decimal.new(0)) do
      {remaining_qty, total_cost, consumed}
    else
      available = layer.remaining_quantity
      to_consume = Decimal.min(available, remaining_qty)
      layer_cost = Decimal.mult(to_consume, layer.unit_cost)

      new_remaining = Decimal.sub(remaining_qty, to_consume)
      new_total = Decimal.add(total_cost, layer_cost)

      consume_from_layers(rest, new_remaining, new_total, [{layer, to_consume} | consumed])
    end
  end

  defp update_stock_level_on_issue(movement, total_cost) do
    level = get_or_create_stock_level(movement)

    new_total = Decimal.sub(level.total_value || Decimal.new(0), total_cost)
    new_total = Decimal.max(new_total, Decimal.new(0))

    # Преизчисляваме средната цена
    new_qty = Decimal.sub(level.quantity_on_hand || Decimal.new(0), movement.quantity)
    new_avg =
      if Decimal.gt?(new_qty, Decimal.new(0)) do
        Decimal.div(new_total, new_qty)
      else
        Decimal.new(0)
      end

    level
    |> StockLevel.changeset(%{average_cost: new_avg, total_value: new_total})
    |> Repo.update!()
  end

  # ============================================================
  # TRANSFER (трансфер)
  # ============================================================

  defp process_transfer(movement, method) do
    # При трансфер: изписваме от source със себестойността, приемаме в target със същата
    # Първо обработваме като изходящо
    source_movement = %{movement | movement_type: "out"}

    case process_outgoing(source_movement, method) do
      {:ok, processed} ->
        # След това създаваме слой в target склада (ако FIFO/LIFO)
        if method in ["fifo", "lifo"] and movement.to_warehouse_id do
          target_layer = %StockCostLayer{
            tenant_id: movement.tenant_id,
            product_id: movement.product_id,
            warehouse_id: movement.to_warehouse_id,
            stock_movement_id: movement.id,
            layer_date: movement.movement_date,
            original_quantity: movement.quantity,
            remaining_quantity: movement.quantity,
            unit_cost: processed.computed_unit_cost,
            status: "active"
          }

          %StockCostLayer{}
          |> StockCostLayer.changeset(Map.from_struct(target_layer))
          |> Repo.insert!()
        end

        # Актуализираме average cost в target склада
        if movement.to_warehouse_id do
          update_average_cost_on_receipt(
            %{movement | warehouse_id: movement.to_warehouse_id},
            processed.computed_unit_cost
          )
        end

        {:ok, processed}

      error ->
        error
    end
  end

  # ============================================================
  # RECALCULATION
  # ============================================================

  defp has_later_movements?(movement) do
    StockMovement
    |> where(
      [m],
      m.tenant_id == ^movement.tenant_id and
        m.product_id == ^movement.product_id and
        m.warehouse_id == ^movement.warehouse_id and
        m.movement_date > ^movement.movement_date and
        m.id != ^movement.id
    )
    |> Repo.exists?()
  end

  defp recalculate_later_movements(movement, method) do
    movements = get_movements_from_date(
      movement.tenant_id,
      movement.product_id,
      movement.warehouse_id,
      Date.add(movement.movement_date, 1)
    )

    Enum.each(movements, fn m ->
      process_by_method(m, method)
    end)
  end

  defp get_movements_from_date(tenant_id, product_id, warehouse_id, from_date) do
    StockMovement
    |> where(
      [m],
      m.tenant_id == ^tenant_id and
        m.product_id == ^product_id and
        m.warehouse_id == ^warehouse_id and
        m.movement_date >= ^from_date
    )
    |> order_by([m], asc: m.movement_date, asc: m.id)
    |> Repo.all()
  end

  defp delete_layers_from_date(tenant_id, product_id, warehouse_id, from_date) do
    StockCostLayer
    |> where(
      [l],
      l.tenant_id == ^tenant_id and
        l.product_id == ^product_id and
        l.warehouse_id == ^warehouse_id and
        l.layer_date >= ^from_date
    )
    |> Repo.delete_all()
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp get_or_create_stock_level(movement) do
    case Repo.get_by(StockLevel,
           tenant_id: movement.tenant_id,
           product_id: movement.product_id,
           warehouse_id: movement.warehouse_id
         ) do
      nil ->
        {:ok, level} =
          %StockLevel{}
          |> StockLevel.changeset(%{
            tenant_id: movement.tenant_id,
            product_id: movement.product_id,
            warehouse_id: movement.warehouse_id,
            quantity_on_hand: Decimal.new(0),
            average_cost: Decimal.new(0),
            total_value: Decimal.new(0)
          })
          |> Repo.insert()

        level

      level ->
        level
    end
  end
end
