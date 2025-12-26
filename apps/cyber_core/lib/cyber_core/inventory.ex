defmodule CyberCore.Inventory do
  @moduledoc """
  Контекст за управление на продукти и складови наличности.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo

  alias CyberCore.Accounting

  alias CyberCore.Inventory.{
    Product,
    Warehouse,
    StockMovement,
    StockLevel,
    Lot,
    LotStockLevel,
    WarehouseLocation,
    StockReservation,
    StockCount,
    StockCountLine,
    MeasurementUnit,
    CnNomenclature
  }

  def list_products(tenant_id, opts \\ []) do
    query =
      from p in Product,
        where: p.tenant_id == ^tenant_id,
        order_by: [asc: p.inserted_at]

    Repo.all(apply_product_filters(query, opts))
  end

  def get_product!(tenant_id, id) do
    Repo.get_by!(Product, tenant_id: tenant_id, id: id)
  end

  @doc """
  Searches products by name, SKU, or description.

  Returns list of matching products with optional limit.
  """
  def search_products(tenant_id, search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    query =
      from p in Product,
        where: p.tenant_id == ^tenant_id,
        where: p.is_active == true,
        order_by: [asc: p.name],
        limit: ^limit

    pattern = "%#{search_term}%"

    from(p in query,
      where:
        ilike(p.name, ^pattern) or
        ilike(p.sku, ^pattern) or
        ilike(p.description, ^pattern)
    )
    |> Repo.all()
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(%Product{} = product), do: Repo.delete(product)

  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  defp apply_product_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:category, nil}, acc ->
        acc

      {:category, category}, acc ->
        from p in acc, where: p.category == ^category

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"

        from p in acc,
          where:
            ilike(p.name, ^pattern) or
              ilike(p.sku, ^pattern) or
              ilike(p.description, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Warehouses --

  def list_warehouses(tenant_id, opts \\ []) do
    query =
      from w in Warehouse,
        where: w.tenant_id == ^tenant_id,
        order_by: [asc: w.code]

    Repo.all(apply_warehouse_filters(query, opts))
  end

  def get_warehouse!(tenant_id, id) do
    Repo.get_by!(Warehouse, tenant_id: tenant_id, id: id)
  end

  def create_warehouse(attrs) do
    %Warehouse{}
    |> Warehouse.changeset(attrs)
    |> Repo.insert()
  end

  def update_warehouse(%Warehouse{} = warehouse, attrs) do
    warehouse
    |> Warehouse.changeset(attrs)
    |> Repo.update()
  end

  def delete_warehouse(%Warehouse{} = warehouse), do: Repo.delete(warehouse)

  def change_warehouse(%Warehouse{} = warehouse, attrs \\ %{}) do
    Warehouse.changeset(warehouse, attrs)
  end

  defp apply_warehouse_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:is_active, value}, acc when is_boolean(value) ->
        from w in acc, where: w.is_active == ^value

      _, acc ->
        acc
    end)
  end

  # -- Stock Movements --

  def list_stock_movements(tenant_id, opts \\ []) do
    query =
      from sm in StockMovement,
        where: sm.tenant_id == ^tenant_id,
        order_by: [desc: sm.movement_date],
        preload: [:product, :warehouse, :to_warehouse]

    Repo.all(apply_movement_filters(query, opts))
  end

  def get_stock_movement!(tenant_id, id) do
    StockMovement
    |> where([sm], sm.tenant_id == ^tenant_id and sm.id == ^id)
    |> preload([:product, :warehouse, :to_warehouse])
    |> Repo.one!()
  end

  def create_stock_movement(attrs) do
    Repo.transaction(fn ->
      with {:ok, movement} <- insert_stock_movement(attrs),
           :ok <- update_stock_levels(movement) do
        Repo.preload(movement, [:product, :warehouse, :to_warehouse])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_stock_movement(attrs) do
    %StockMovement{}
    |> StockMovement.changeset(attrs)
    |> Repo.insert()
  end

  defp update_stock_levels(%StockMovement{} = movement) do
    case movement.movement_type do
      "in" -> update_stock_in(movement)
      "surplus" -> update_stock_in(movement)
      "out" -> update_stock_out(movement)
      "scrapping" -> update_stock_out(movement)
      "shortage" -> update_stock_out(movement)
      "transfer" -> update_stock_transfer(movement)
      "adjustment" -> update_stock_adjustment(movement)
      _ -> :ok
    end
  end

  defp update_stock_in(movement) do
    level =
      get_or_create_stock_level(movement.tenant_id, movement.product_id, movement.warehouse_id)

    new_qty = Decimal.add(level.quantity_on_hand, movement.quantity)

    level
    |> StockLevel.changeset(%{quantity_on_hand: new_qty})
    |> Repo.update()

    :ok
  end

  defp update_stock_out(movement) do
    level =
      get_or_create_stock_level(movement.tenant_id, movement.product_id, movement.warehouse_id)

    new_qty = Decimal.sub(level.quantity_on_hand, movement.quantity)

    if Decimal.lt?(new_qty, Decimal.new(0)) do
      {:error, "Insufficient stock"}
    else
      level
      |> StockLevel.changeset(%{quantity_on_hand: new_qty})
      |> Repo.update()

      :ok
    end
  end

  defp update_stock_transfer(movement) do
    # Намаляване от изходен склад
    from_level =
      get_or_create_stock_level(movement.tenant_id, movement.product_id, movement.warehouse_id)

    new_from_qty = Decimal.sub(from_level.quantity_on_hand, movement.quantity)

    if Decimal.lt?(new_from_qty, Decimal.new(0)) do
      {:error, "Insufficient stock in source warehouse"}
    else
      # Увеличаване в целеви склад
      to_level =
        get_or_create_stock_level(
          movement.tenant_id,
          movement.product_id,
          movement.to_warehouse_id
        )

      new_to_qty = Decimal.add(to_level.quantity_on_hand, movement.quantity)

      from_level
      |> StockLevel.changeset(%{quantity_on_hand: new_from_qty})
      |> Repo.update()

      to_level
      |> StockLevel.changeset(%{quantity_on_hand: new_to_qty})
      |> Repo.update()

      :ok
    end
  end

  defp update_stock_adjustment(movement) do
    level =
      get_or_create_stock_level(movement.tenant_id, movement.product_id, movement.warehouse_id)

    level
    |> StockLevel.changeset(%{quantity_on_hand: movement.quantity})
    |> Repo.update()

    :ok
  end

  defp get_or_create_stock_level(tenant_id, product_id, warehouse_id) do
    case Repo.get_by(StockLevel,
           tenant_id: tenant_id,
           product_id: product_id,
           warehouse_id: warehouse_id
         ) do
      nil ->
        {:ok, level} =
          %StockLevel{}
          |> StockLevel.changeset(%{
            tenant_id: tenant_id,
            product_id: product_id,
            warehouse_id: warehouse_id,
            quantity_on_hand: Decimal.new(0)
          })
          |> Repo.insert()

        level

      level ->
        level
    end
  end

  defp apply_movement_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:warehouse_id, id}, acc when is_integer(id) ->
        from sm in acc, where: sm.warehouse_id == ^id

      {:product_id, id}, acc when is_integer(id) ->
        from sm in acc, where: sm.product_id == ^id

      {:movement_type, type}, acc when type != nil ->
        from sm in acc, where: sm.movement_type == ^type

      {:status, status}, acc when status != nil ->
        from sm in acc, where: sm.status == ^status

      _, acc ->
        acc
    end)
  end

  # -- Stock Levels --

  def list_stock_levels(tenant_id, opts \\ []) do
    query =
      from sl in StockLevel,
        where: sl.tenant_id == ^tenant_id,
        preload: [:product, :warehouse],
        order_by: [asc: :product_id]

    Repo.all(apply_stock_level_filters(query, opts))
  end

  def get_stock_level(tenant_id, product_id, warehouse_id) do
    Repo.get_by(StockLevel,
      tenant_id: tenant_id,
      product_id: product_id,
      warehouse_id: warehouse_id
    )
  end

  defp apply_stock_level_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:warehouse_id, id}, acc when is_integer(id) ->
        from sl in acc, where: sl.warehouse_id == ^id

      {:product_id, id}, acc when is_integer(id) ->
        from sl in acc, where: sl.product_id == ^id

      {:low_stock, true}, acc ->
        from sl in acc, where: sl.quantity_on_hand <= sl.reorder_point

      _, acc ->
        acc
    end)
  end

  # -- Lots (Партиди) --

  def list_lots(tenant_id, opts \\ []) do
    query =
      from l in Lot,
        where: l.tenant_id == ^tenant_id,
        preload: [:product],
        order_by: [desc: l.inserted_at]

    Repo.all(apply_lot_filters(query, opts))
  end

  def get_lot!(tenant_id, id) do
    Lot
    |> where([l], l.tenant_id == ^tenant_id and l.id == ^id)
    |> preload([:product, :lot_stock_levels])
    |> Repo.one!()
  end

  def create_lot(attrs) do
    %Lot{}
    |> Lot.changeset(attrs)
    |> Repo.insert()
  end

  def update_lot(%Lot{} = lot, attrs) do
    lot
    |> Lot.changeset(attrs)
    |> Repo.update()
  end

  def delete_lot(%Lot{} = lot), do: Repo.delete(lot)

  def change_lot(%Lot{} = lot, attrs \\ %{}) do
    Lot.changeset(lot, attrs)
  end

  @doc """
  Намира партиди, които изтичат скоро (в рамките на указаните дни).
  """
  def list_expiring_lots(tenant_id, days \\ 30) do
    threshold = Date.add(Date.utc_today(), days)

    from(l in Lot,
      where:
        l.tenant_id == ^tenant_id and
          l.is_active == true and
          not is_nil(l.expiry_date) and
          l.expiry_date <= ^threshold,
      order_by: [asc: l.expiry_date],
      preload: [:product]
    )
    |> Repo.all()
  end

  defp apply_lot_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:product_id, id}, acc when is_integer(id) ->
        from l in acc, where: l.product_id == ^id

      {:is_active, value}, acc when is_boolean(value) ->
        from l in acc, where: l.is_active == ^value

      {:expired, true}, acc ->
        today = Date.utc_today()
        from l in acc, where: l.expiry_date < ^today

      {:expiring_soon, days}, acc when is_integer(days) ->
        threshold = Date.add(Date.utc_today(), days)
        from l in acc, where: l.expiry_date <= ^threshold

      _, acc ->
        acc
    end)
  end

  # -- Warehouse Locations (Складови локации) --

  def list_warehouse_locations(tenant_id, opts \\ []) do
    query =
      from wl in WarehouseLocation,
        where: wl.tenant_id == ^tenant_id,
        preload: [:warehouse],
        order_by: [asc: wl.code]

    Repo.all(apply_location_filters(query, opts))
  end

  def get_warehouse_location!(tenant_id, id) do
    WarehouseLocation
    |> where([wl], wl.tenant_id == ^tenant_id and wl.id == ^id)
    |> preload([:warehouse])
    |> Repo.one!()
  end

  def create_warehouse_location(attrs) do
    %WarehouseLocation{}
    |> WarehouseLocation.changeset(attrs)
    |> Repo.insert()
  end

  def update_warehouse_location(%WarehouseLocation{} = location, attrs) do
    location
    |> WarehouseLocation.changeset(attrs)
    |> Repo.update()
  end

  def delete_warehouse_location(%WarehouseLocation{} = location), do: Repo.delete(location)

  def change_warehouse_location(%WarehouseLocation{} = location, attrs \\ %{}) do
    WarehouseLocation.changeset(location, attrs)
  end

  defp apply_location_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:warehouse_id, id}, acc when is_integer(id) ->
        from wl in acc, where: wl.warehouse_id == ^id

      {:is_active, value}, acc when is_boolean(value) ->
        from wl in acc, where: wl.is_active == ^value

      {:zone, zone}, acc when is_binary(zone) ->
        from wl in acc, where: wl.zone == ^zone

      _, acc ->
        acc
    end)
  end

  # -- Stock Reservations (Резервации) --

  def list_stock_reservations(tenant_id, opts \\ []) do
    query =
      from sr in StockReservation,
        where: sr.tenant_id == ^tenant_id,
        preload: [:product, :warehouse, :lot],
        order_by: [desc: sr.inserted_at]

    Repo.all(apply_reservation_filters(query, opts))
  end

  def get_stock_reservation!(tenant_id, id) do
    StockReservation
    |> where([sr], sr.tenant_id == ^tenant_id and sr.id == ^id)
    |> preload([:product, :warehouse, :lot])
    |> Repo.one!()
  end

  def create_stock_reservation(attrs) do
    Repo.transaction(fn ->
      with {:ok, reservation} <- insert_stock_reservation(attrs),
           :ok <- reserve_stock(reservation) do
        Repo.preload(reservation, [:product, :warehouse, :lot])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_stock_reservation(attrs) do
    %StockReservation{}
    |> StockReservation.changeset(attrs)
    |> Repo.insert()
  end

  defp reserve_stock(%StockReservation{lot_id: lot_id} = reservation)
       when not is_nil(lot_id) do
    # Резервация с партида
    level =
      get_or_create_lot_stock_level(
        reservation.tenant_id,
        reservation.lot_id,
        reservation.warehouse_id
      )

    new_reserved = Decimal.add(level.quantity_reserved, reservation.quantity)

    level
    |> LotStockLevel.changeset(%{quantity_reserved: new_reserved})
    |> Repo.update()

    :ok
  end

  defp reserve_stock(%StockReservation{} = _reservation) do
    # Резервация без партида
    # TODO: Добавяме quantity_reserved в StockLevel schema
    :ok
  end

  def cancel_stock_reservation(%StockReservation{} = reservation) do
    Repo.transaction(fn ->
      with :ok <- release_stock(reservation),
           {:ok, updated} <-
             reservation
             |> StockReservation.changeset(%{status: "cancelled"})
             |> Repo.update() do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp release_stock(%StockReservation{lot_id: lot_id} = reservation)
       when not is_nil(lot_id) do
    case Repo.get_by(LotStockLevel,
           tenant_id: reservation.tenant_id,
           lot_id: reservation.lot_id,
           warehouse_id: reservation.warehouse_id
         ) do
      nil ->
        :ok

      level ->
        new_reserved = Decimal.sub(level.quantity_reserved, reservation.quantity)
        new_reserved = Decimal.max(new_reserved, Decimal.new(0))

        level
        |> LotStockLevel.changeset(%{quantity_reserved: new_reserved})
        |> Repo.update()

        :ok
    end
  end

  defp release_stock(_reservation), do: :ok

  defp apply_reservation_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when is_binary(status) ->
        from sr in acc, where: sr.status == ^status

      {:product_id, id}, acc when is_integer(id) ->
        from sr in acc, where: sr.product_id == ^id

      {:warehouse_id, id}, acc when is_integer(id) ->
        from sr in acc, where: sr.warehouse_id == ^id

      {:reservation_type, type}, acc when is_binary(type) ->
        from sr in acc, where: sr.reservation_type == ^type

      _, acc ->
        acc
    end)
  end

  defp get_or_create_lot_stock_level(tenant_id, lot_id, warehouse_id) do
    case Repo.get_by(LotStockLevel,
           tenant_id: tenant_id,
           lot_id: lot_id,
           warehouse_id: warehouse_id
         ) do
      nil ->
        {:ok, level} =
          %LotStockLevel{}
          |> LotStockLevel.changeset(%{
            tenant_id: tenant_id,
            lot_id: lot_id,
            warehouse_id: warehouse_id,
            quantity_on_hand: Decimal.new(0),
            quantity_reserved: Decimal.new(0)
          })
          |> Repo.insert()

        level

      level ->
        level
    end
  end

  # -- Stock Counts (Инвентаризация) --

  def list_stock_counts(tenant_id, opts \\ []) do
    query =
      from sc in StockCount,
        where: sc.tenant_id == ^tenant_id,
        preload: [:warehouse],
        order_by: [desc: sc.count_date]

    Repo.all(apply_stock_count_filters(query, opts))
  end

  def get_stock_count!(tenant_id, id) do
    StockCount
    |> where([sc], sc.tenant_id == ^tenant_id and sc.id == ^id)
    |> preload([:warehouse, count_lines: [:product, :lot, :location]])
    |> Repo.one!()
  end

  def create_stock_count(attrs) do
    %StockCount{}
    |> StockCount.changeset(attrs)
    |> Repo.insert()
  end

  def update_stock_count(%StockCount{} = stock_count, attrs) do
    stock_count
    |> StockCount.changeset(attrs)
    |> Repo.update()
  end

  def delete_stock_count(%StockCount{} = stock_count), do: Repo.delete(stock_count)

  def change_stock_count(%StockCount{} = stock_count, attrs \\ %{}) do
    StockCount.changeset(stock_count, attrs)
  end

  @doc """
  Добавя ред към инвентаризация.
  """
  def add_stock_count_line(%StockCount{} = stock_count, attrs) do
    attrs = Map.put(attrs, "stock_count_id", stock_count.id)

    %StockCountLine{}
    |> StockCountLine.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Завършва инвентаризация и приложи корекции.
  """
  def complete_stock_count(%StockCount{} = stock_count, user_id) do
    Repo.transaction(fn ->
      lines = Repo.preload(stock_count, :count_lines).count_lines

      # Прилагане на корекции
      Enum.each(lines, fn line ->
        variance = StockCountLine.calculate_variance(line).variance || Decimal.new(0)

        unless Decimal.eq?(variance, 0) do
          # Създаване на adjustment движение
          create_stock_movement(%{
            tenant_id: stock_count.tenant_id,
            product_id: line.product_id,
            warehouse_id: stock_count.warehouse_id,
            movement_type: "adjustment",
            movement_date: NaiveDateTime.utc_now(),
            quantity: Decimal.abs(variance),
            notes: "Корекция от инвентаризация #{stock_count.count_number}",
            reference_type: "stock_count",
            reference_id: stock_count.id
          })
        end
      end)

      # Актуализация на статуса
      stock_count
      |> StockCount.changeset(%{
        status: "completed",
        completed_at: NaiveDateTime.utc_now(),
        completed_by_id: user_id
      })
      |> Repo.update!()
    end)
  end

  defp apply_stock_count_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:warehouse_id, id}, acc when is_integer(id) ->
        from sc in acc, where: sc.warehouse_id == ^id

      {:status, status}, acc when is_binary(status) ->
        from sc in acc, where: sc.status == ^status

      _, acc ->
        acc
    end)
  end

  # -- Measurement Units --

  @doc """
  Връща списък с всички мерни единици.
  """
  def list_measurement_units do
    Repo.all(from mu in MeasurementUnit, order_by: [asc: mu.code])
  end

  @doc """
  Взима мерна единица по ID.
  """
  def get_measurement_unit(id) do
    Repo.get(MeasurementUnit, id)
  end

  @doc """
  Взима мерна единица по код.
  """
  def get_measurement_unit_by_code(code) do
    Repo.get_by(MeasurementUnit, code: code)
  end

  @doc """
  Създава нова мерна единица.
  """
  def create_measurement_unit(attrs) do
    %MeasurementUnit{}
    |> MeasurementUnit.changeset(attrs)
    |> Repo.insert()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_units/1)
  end

  @doc """
  Обновява мерна единица.
  """
  def update_measurement_unit(%MeasurementUnit{} = unit, attrs) do
    unit
    |> MeasurementUnit.changeset(attrs)
    |> Repo.update()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_unit/1)
  end

  @doc """
  Изтрива мерна единица.
  """
  def delete_measurement_unit(%MeasurementUnit{} = unit) do
    result = Repo.delete(unit)
    CyberCore.Cache.Invalidator.invalidate_measurement_units()
    result
  end

  # -- CN Nomenclature --

  @doc """
  Взима КН номенклатура по ID.
  """
  def get_cn_nomenclature(id) do
    Repo.get(CnNomenclature, id)
  end

  @doc """
  Взима КН номенклатура по код и година.
  """
  def get_cn_nomenclature_by_code(code, year) do
    Repo.get_by(CnNomenclature, code: code, year: year)
  end

  @doc """
  Търси КН номенклатури по префикс на кода.
  """
  def search_cn_nomenclature(prefix, year, limit \\ 20) do
    pattern = "#{prefix}%"

    query =
      from cn in CnNomenclature,
        where: cn.year == ^year and like(cn.code, ^pattern),
        order_by: [asc: cn.code],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Списък с КН номенклатури за дадена година.
  """
  def list_cn_nomenclatures(year, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    query =
      from cn in CnNomenclature,
        where: cn.year == ^year,
        order_by: [asc: cn.code],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Създава КН номенклатура.
  """
  def create_cn_nomenclature(attrs) do
    %CnNomenclature{}
    |> CnNomenclature.changeset(attrs)
    |> Repo.insert()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_cn_code/1)
  end

  @doc """
  Обновява КН номенклатура.
  """
  def update_cn_nomenclature(%CnNomenclature{} = cn, attrs) do
    cn
    |> CnNomenclature.changeset(attrs)
    |> Repo.update()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_cn_code/1)
  end

  @doc """
  Изтрива КН номенклатура.
  """
  def delete_cn_nomenclature(%CnNomenclature{} = cn) do
    result = Repo.delete(cn)
    CyberCore.Cache.Invalidator.invalidate_nomenclatures()
    result
  end

  @doc """
  Връща списък с продукти, които имат зададени начални салда.
  """
  def list_products_with_opening_balances(tenant_id) do
    from(p in Product,
      where: p.tenant_id == ^tenant_id and p.opening_quantity > 0,
      order_by: [asc: p.sku]
    )
    |> Repo.all()
  end

  @doc """
  Премахва началното салдо за продукт.
  """
  def remove_opening_balance(tenant_id, product_id) do
    product = get_product!(tenant_id, product_id)
    
    product
    |> Product.changeset(%{
      opening_quantity: Decimal.new(0),
      opening_cost: Decimal.new(0)
    })
    |> Repo.update()
  end

  @doc """
  Задава начални салда за продукт в склада.
  
  Тази функция създава начално движение за продукт в склада с определено количество и цена.
  """
  def set_opening_balance(tenant_id, product_id, warehouse_id, quantity, cost) do
    product = get_product!(tenant_id, product_id)
    warehouse = get_warehouse!(tenant_id, warehouse_id)

    # Актуализиране на продукта с началните количества
    product
    |> Product.changeset(%{
      opening_quantity: quantity,
      opening_cost: cost
    })
    |> Repo.update()

    # Създаване на складово движение за началното салдо
    level = get_or_create_stock_level(tenant_id, product_id, warehouse_id)

    level
    |> StockLevel.changeset(%{
      quantity_on_hand: quantity,
      average_cost: cost
    })
    |> Repo.update()

    # Създаване на счетоводен запис за началното салдо
    create_opening_journal_entry(tenant_id, product, warehouse, quantity, cost)
  end
  
  defp create_opening_journal_entry(tenant_id, product, warehouse, quantity, cost) do
    total_cost = Decimal.mult(quantity, cost)
    today = Date.utc_today()

    lines = [
      %{
        account_id: get_inventory_account_id(tenant_id),
        debit_amount: total_cost,
        credit_amount: Decimal.new(0),
        description: "Начално салдо за #{product.name}"
      },
      %{
        account_id: get_equity_account_id(tenant_id),
        debit_amount: Decimal.new(0),
        credit_amount: total_cost,
        description: "Начално салдо за #{product.name}"
      }
    ]

    Accounting.create_journal_entry_with_lines(
      %{
        tenant_id: tenant_id,
        document_type: "opening_balance",
        document_number: "OB-#{product.id}-#{warehouse.id}",
        document_date: today,
        description: "Начално салдо за #{product.name} в склад #{warehouse.name}",
        accounting_date: today,
        is_posted: true,
        source_document_id: product.id,
        source_document_type: "ProductOpeningBalance"
      },
      lines
    )
  end
  
  defp get_inventory_account_id(tenant_id) do
    # Търсене на стандартната сметка за складови запаси
    case Accounting.get_account_by_code("302", tenant_id) do
      nil -> raise "Не е намерена сметка 302 за складови запаси"
      account -> account.id
    end
  end

  defp get_equity_account_id(tenant_id) do
    # Търсене на стандартната капиталова сметка
    case Accounting.get_account_by_code("801", tenant_id) do
      nil -> raise "Не е намерена сметка 801 за уставен капитал"
      account -> account.id
    end
  end

  def create_goods_receipt(attrs, lines) do
    Repo.transaction(fn ->
      for line <- lines do
        movement_attrs = %{
          tenant_id: attrs["tenant_id"],
          warehouse_id: attrs["warehouse_id"],
          movement_type: "in",
          movement_date: Date.utc_today(),
          product_id: line["product_id"],
          quantity: line["quantity"],
          notes: "Приемане на стока",
          reference_type: "goods_receipt"
        }
        create_stock_movement(movement_attrs)
      end
    end)
  end

  def create_goods_issue(attrs, lines) do
    Repo.transaction(fn ->
      for line <- lines do
        movement_attrs = %{
          tenant_id: attrs["tenant_id"],
          warehouse_id: attrs["warehouse_id"],
          movement_type: "out",
          movement_date: Date.utc_today(),
          product_id: line["product_id"],
          quantity: line["quantity"],
          notes: "Издаване на стока",
          reference_type: "goods_issue"
        }
        create_stock_movement(movement_attrs)
      end
    end)
  end

  def create_stock_transfer(attrs, lines) do
    Repo.transaction(fn ->
      for line <- lines do
        movement_attrs = %{
          tenant_id: attrs["tenant_id"],
          warehouse_id: attrs["from_warehouse_id"],
          to_warehouse_id: attrs["to_warehouse_id"],
          movement_type: "transfer",
          movement_date: Date.utc_today(),
          product_id: line["product_id"],
          quantity: line["quantity"],
          notes: "Трансфер между складове"
        }
        create_stock_movement(movement_attrs)
      end
    end)
  end

  @doc """
  Създава корекция на наличност - Брак, Липса или Излишък.

  ## Типове:
  - "scrap" - Брак (намалява наличност)
  - "shortage" - Липса (намалява наличност)
  - "surplus" - Излишък (увеличава наличност)
  """
  def create_stock_adjustment(attrs, lines) do
    adjustment_type = attrs["adjustment_type"]

    {movement_type, notes_prefix} =
      case adjustment_type do
        "scrap" -> {"out", "Брак"}
        "shortage" -> {"out", "Липса"}
        "surplus" -> {"in", "Излишък"}
        _ -> {"out", "Корекция"}
      end

    Repo.transaction(fn ->
      for line <- lines do
        reason = if line["reason"] && line["reason"] != "", do: " - #{line["reason"]}", else: ""

        movement_attrs = %{
          tenant_id: attrs["tenant_id"],
          warehouse_id: attrs["warehouse_id"],
          movement_type: movement_type,
          movement_date: Date.utc_today(),
          product_id: line["product_id"],
          quantity: line["quantity"],
          unit_cost: line["unit_cost"],
          notes: "#{notes_prefix}#{reason}",
          reference_type: "stock_adjustment",
          reference_id: nil
        }

        create_stock_movement(movement_attrs)
      end
    end)
  end
end
