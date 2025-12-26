# Оценка на материалните запаси

## Общ преглед

Системата поддържа три метода за оценка на материалните запаси:

| Метод | Код | Описание |
|-------|-----|----------|
| Средно претеглена цена | `weighted_average` | Себестойността е средна стойност от всички доставки |
| FIFO | `fifo` | First In, First Out - първо се изписват най-старите доставки |
| LIFO | `lifo` | Last In, First Out - първо се изписват най-новите доставки |

**Важно:** Методът за оценка се задава на ниво **склад**, не на ниво продукт.

## Настройка

### 1. Задаване на метод за склад

```elixir
# При създаване на склад
Inventory.create_warehouse(%{
  tenant_id: 1,
  code: "MAIN",
  name: "Основен склад",
  costing_method: "fifo"  # или "lifo", "weighted_average"
})

# При редактиране
Inventory.update_warehouse(warehouse, %{costing_method: "weighted_average"})
```

### 2. Задаване на счетоводни сметки за продукти

Всеки продукт има три счетоводни сметки:

| Поле | Описание | Примери по категория |
|------|----------|---------------------|
| `account_id` | Инвентарна сметка | 304 (стоки), 302 (материали), 303 (продукция) |
| `expense_account_id` | Сметка за разход | 702 (стоки), 601 (материали), 611 (продукция) |
| `revenue_account_id` | Сметка за приходи | 702 (стоки), null (материали) |

```elixir
Inventory.create_product(%{
  tenant_id: 1,
  name: "Продукт А",
  sku: "PROD-A",
  category: "goods",
  account_id: 304,           # Инвентарна сметка
  expense_account_id: 702,   # Себестойност на продажби
  revenue_account_id: 702    # Приходи от продажби
})
```

## Архитектура

### Таблици

#### `stock_cost_layers`
Съхранява "слоеве" за FIFO/LIFO оценка:

```sql
CREATE TABLE stock_cost_layers (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  warehouse_id INTEGER NOT NULL,
  stock_movement_id INTEGER,
  layer_date DATE NOT NULL,
  original_quantity DECIMAL(15,4) NOT NULL,
  remaining_quantity DECIMAL(15,4) NOT NULL,
  unit_cost DECIMAL(15,4) NOT NULL,
  status VARCHAR DEFAULT 'active'  -- active, depleted
);
```

#### `stock_movements` (разширения)

```sql
ALTER TABLE stock_movements ADD COLUMN unit_cost DECIMAL(15,4);
ALTER TABLE stock_movements ADD COLUMN computed_unit_cost DECIMAL(15,4);
ALTER TABLE stock_movements ADD COLUMN computed_total_cost DECIMAL(15,4);
```

### Модули

#### `CyberCore.Inventory.CostingEngine`

Основен модул за изчисляване на себестойност.

```elixir
# Обработва движение и изчислява себестойност
{:ok, movement} = CostingEngine.process_movement(movement)

# Преизчисляване от дата (при ретроактивни документи)
CostingEngine.recalculate_from_date(tenant_id, product_id, warehouse_id, ~D[2025-01-01])

# Текуща средна цена
avg_cost = CostingEngine.get_average_cost(tenant_id, product_id, warehouse_id)

# Активни слоеве (за FIFO/LIFO)
layers = CostingEngine.get_active_layers(tenant_id, product_id, warehouse_id)
```

## Типове движения

### Входящи (създават слой при FIFO/LIFO)
- `in` - Приход от доставчик
- `purchase` - Покупка
- `surplus` - Излишък при инвентаризация
- `production_receipt` - Приход от производство
- `opening_balance` - Начално салдо

### Изходящи (консумират слоеве)
- `out` - Разход
- `sale` - Продажба
- `shortage` - Липса при инвентаризация
- `scrapping` - Брак
- `production_issue` - Изписване за производство

### Други
- `transfer` - Прехвърляне между складове (изписва от source, приема в target)
- `adjustment` - Корекция

## Алгоритми

### Weighted Average (Средно претеглена)

**При приемане:**
```
new_avg = (old_qty * old_avg + new_qty * new_cost) / (old_qty + new_qty)
```

**При изписване:**
```
cost = quantity * current_avg
```

### FIFO (First In, First Out)

**При приемане:**
- Създава нов слой с дата, количество и цена

**При изписване:**
- Консумира от най-старите слоеве (подредени по `layer_date ASC`)
- Изчислява среднопретеглена цена от консумираните слоеве

### LIFO (Last In, First Out)

**При приемане:**
- Създава нов слой с дата, количество и цена

**При изписване:**
- Консумира от най-новите слоеве (подредени по `layer_date DESC`)
- Изчислява среднопретеглена цена от консумираните слоеве

## Ретроактивни документи

При въвеждане на документ с минала дата, системата автоматично преизчислява всички следващи движения за съответния продукт/склад.

```elixir
# Автоматично при process_movement
# Ако movement.movement_date < последното движение
#   -> преизчислява всички следващи движения
```

## Производство

При стартиране на производствена поръчка:

1. **Изписване на материали** (`production_issue`)
   - Дт 601 (разход за материали) / Кт 302 (материали)
   - Себестойността се изчислява според метода на склада

2. **Заприходяване на готова продукция** (`production_receipt`)
   - Дт 303 (готова продукция) / Кт 611 (производствени разходи)
   - Себестойността е сумата от материали + труд + машини

## Ограничения

- **Услугите** (`category: "services"`) не са материални запаси и не подлежат на оценка
- **Отрицателни наличности** не са позволени при FIFO/LIFO (ще върне грешка)
- **Смяна на метод** в склад с налични слоеве изисква преизчисляване

## Примери

### Пример 1: Weighted Average

```
Начално: 0 бр, 0 лв

1. Приемане: 100 бр x 10 лв = 1000 лв
   -> Средна цена: 10 лв

2. Приемане: 50 бр x 12 лв = 600 лв
   -> Средна цена: (1000 + 600) / 150 = 10.67 лв

3. Изписване: 80 бр
   -> Себестойност: 80 x 10.67 = 853.60 лв
   -> Остават: 70 бр x 10.67 = 746.90 лв
```

### Пример 2: FIFO

```
Начално: 0 бр

1. Приемане: 100 бр x 10 лв (Слой 1)
2. Приемане: 50 бр x 12 лв (Слой 2)

3. Изписване: 80 бр
   -> Консумира от Слой 1: 80 бр x 10 лв = 800 лв
   -> Остава Слой 1: 20 бр x 10 лв
   -> Остава Слой 2: 50 бр x 12 лв
```

### Пример 3: LIFO

```
Начално: 0 бр

1. Приемане: 100 бр x 10 лв (Слой 1)
2. Приемане: 50 бр x 12 лв (Слой 2)

3. Изписване: 80 бр
   -> Консумира от Слой 2: 50 бр x 12 лв = 600 лв
   -> Консумира от Слой 1: 30 бр x 10 лв = 300 лв
   -> Общо: 900 лв
   -> Остава Слой 1: 70 бр x 10 лв
```

## Бъдещи разширения

- [ ] Периодично приключване (заключване на периоди)
- [ ] Справки по слоеве
- [ ] Експорт за счетоводен софтуер
