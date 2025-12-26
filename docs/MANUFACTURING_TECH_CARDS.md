# Модул Производство - Технологични карти

## Обзор

Модулът за производство е преработен с нова архитектура базирана на **технологични карти** вместо прости рецепти. Новата система предлага:

- Работни центрове (машини, станции, линии)
- Технологични карти с материали и операции
- Формули за изчисление на количества и времена
- Коефициенти за гъвкаво калкулиране
- Проследяване на разходи (планирани vs реални)
- Контрол на качеството

## Структура на модула

```
Manufacturing
├── WorkCenter          # Работни центрове
├── TechCard            # Технологични карти
│   ├── TechCardMaterial    # Материали (BOM)
│   └── TechCardOperation   # Операции
├── ProductionOrder     # Производствени поръчки
│   ├── ProductionOrderMaterial   # Материали за поръчка
│   └── ProductionOrderOperation  # Операции в поръчка
├── FormulaEngine       # Двигател за формули
└── Recipe (legacy)     # Стари рецепти (за съвместимост)
```

## Работни центрове (WorkCenter)

Работните центрове представляват физическите места където се извършва производството.

### Полета

| Поле | Тип | Описание |
|------|-----|----------|
| code | string | Уникален код (напр. "WC-001") |
| name | string | Име на центъра |
| center_type | enum | Тип: machine, workstation, assembly_line, manual, outsourced |
| hourly_rate | decimal | Часова ставка (лв/час) |
| capacity_per_hour | decimal | Капацитет на час |
| efficiency_percent | decimal | Ефективност (%) |
| is_active | boolean | Активен ли е |

### Типове работни центрове

- **machine** - Машина (CNC, преса, etc.)
- **workstation** - Работна станция (ръчна работа)
- **assembly_line** - Монтажна линия
- **manual** - Ръчен труд
- **outsourced** - Външен изпълнител

### Пример за използване

```elixir
# Създаване на работен център
Manufacturing.create_work_center(%{
  tenant_id: 1,
  code: "CNC-01",
  name: "CNC Фреза",
  center_type: "machine",
  hourly_rate: Decimal.new("45.00"),
  capacity_per_hour: Decimal.new("10"),
  efficiency_percent: Decimal.new("85")
})
```

## Технологични карти (TechCard)

Технологичната карта дефинира как се произвежда даден продукт.

### Полета

| Поле | Тип | Описание |
|------|-----|----------|
| code | string | Уникален код (напр. "TC-001") |
| name | string | Име на картата |
| output_product_id | integer | Краен продукт |
| output_quantity | decimal | Количество което се произвежда |
| output_unit | string | Мерна единица |
| version | string | Версия (напр. "1.0", "2.1") |
| valid_from | date | Валидна от дата |
| valid_to | date | Валидна до дата |
| overhead_percent | decimal | Overhead % от преки разходи |
| is_active | boolean | Активна ли е |

### Изчислени разходи

- **material_cost** - Разходи за материали
- **labor_cost** - Разходи за труд
- **machine_cost** - Разходи за машини
- **overhead_cost** - Непреки разходи
- **total_cost** - Общ разход

## Материали в технологична карта (TechCardMaterial)

Дефинира материалите (BOM - Bill of Materials) за технологичната карта.

### Полета

| Поле | Тип | Описание |
|------|-----|----------|
| product_id | integer | Продукт/материал |
| line_no | integer | Пореден номер |
| quantity | decimal | Базово количество |
| unit | string | Мерна единица |
| coefficient | decimal | Коефициент (множител) |
| wastage_percent | decimal | Процент брак/загуби |
| quantity_formula | string | Формула за изчисление (опционална) |
| unit_cost | decimal | Единична цена |
| is_fixed | boolean | Фиксиран материал (не зависи от количеството) |

### Изчисляване на количество

Ако няма формула, се използва стандартната:

```
ефективно_количество = quantity × coefficient × output_quantity × (1 + wastage_percent/100)
```

За фиксирани материали (`is_fixed = true`):
```
ефективно_количество = quantity × coefficient × (1 + wastage_percent/100)
```

### Примери за формули

```
# Базова формула
quantity * coefficient

# С брак
quantity * coefficient * (1 + wastage_percent / 100)

# Отстъпка за големи количества
if(output_quantity > 100, quantity * 0.95, quantity)

# Закръгляване
round(quantity * coefficient, 2)

# Минимално количество
max(quantity * output_quantity, 1)
```

## Операции в технологична карта (TechCardOperation)

Дефинира работните стъпки за производство.

### Полета

| Поле | Тип | Описание |
|------|-----|----------|
| sequence_no | integer | Пореден номер |
| work_center_id | integer | Работен център |
| operation_code | string | Код на операцията |
| name | string | Име на операцията |
| setup_time | decimal | Време за настройка (мин) |
| run_time_per_unit | decimal | Време за единица (мин) |
| wait_time | decimal | Време за изчакване (мин) |
| move_time | decimal | Време за преместване (мин) |
| time_coefficient | decimal | Времеви коефициент |
| efficiency_coefficient | decimal | Коефициент на ефективност |
| time_formula | string | Формула за време (опционална) |
| labor_rate_per_hour | decimal | Часова ставка за труд |
| machine_rate_per_hour | decimal | Часова ставка за машина |
| requires_qc | boolean | Изисква контрол на качеството |
| qc_instructions | text | Инструкции за QC |
| tools_required | text | Необходими инструменти |
| setup_instructions | text | Инструкции за настройка |

### Изчисляване на време

Стандартна формула:
```
време = (setup_time + run_time_per_unit × quantity + wait_time + move_time) × time_coefficient / efficiency_coefficient
```

### Примери за формули за време

```
# Базова формула
setup_time + run_time_per_unit * quantity

# Намален setup за големи серии
if(quantity > 1000, setup_time * 0.5, setup_time) + run_time_per_unit * quantity

# С времеви коефициент
(setup_time + run_time_per_unit * quantity) * time_coefficient

# С ефективност
(setup_time + run_time_per_unit * quantity) / efficiency_coefficient
```

## FormulaEngine - Двигател за формули

Безопасен двигател за изчисляване на математически изрази.

### Поддържани операции

- Аритметични: `+`, `-`, `*`, `/`
- Сравнения: `>`, `<`, `>=`, `<=`, `==`, `!=`
- Скоби: `(`, `)`

### Поддържани функции

| Функция | Описание | Пример |
|---------|----------|--------|
| `round(x)` | Закръгляване | `round(3.7)` → 4 |
| `round(x, n)` | Закръгляване до n знака | `round(3.567, 2)` → 3.57 |
| `ceil(x)` | Закръгляване нагоре | `ceil(3.2)` → 4 |
| `floor(x)` | Закръгляване надолу | `floor(3.8)` → 3 |
| `abs(x)` | Абсолютна стойност | `abs(-5)` → 5 |
| `min(a, b)` | Минимум | `min(3, 7)` → 3 |
| `max(a, b)` | Максимум | `max(3, 7)` → 7 |
| `if(cond, a, b)` | Условие | `if(x > 10, 1, 0)` |

### Променливи за материали

- `quantity` - Базово количество
- `coefficient` - Коефициент
- `wastage_percent` - Процент брак
- `output_quantity` - Количество продукция
- `is_fixed` - Фиксиран материал (0 или 1)

### Променливи за операции

- `setup_time` - Време за настройка (мин)
- `run_time_per_unit` - Време за единица (мин)
- `wait_time` - Време за изчакване (мин)
- `move_time` - Време за преместване (мин)
- `time_coefficient` - Времеви коефициент
- `efficiency_coefficient` - Коефициент на ефективност
- `quantity` - Количество за производство

### Примери

```elixir
# Валидиране на формула
FormulaEngine.validate_formula("quantity * coefficient")
# => :ok

FormulaEngine.validate_formula("System.cmd('rm', ['-rf', '/'])")
# => {:error, "Формулата съдържа забранени функции"}

# Изчисляване
FormulaEngine.evaluate("quantity * coefficient * (1 + wastage_percent / 100)", %{
  quantity: Decimal.new(10),
  coefficient: Decimal.new("1.2"),
  wastage_percent: Decimal.new(5)
})
# => Decimal.new("12.6")
```

## Производствени поръчки (ProductionOrder)

### Статуси

| Статус | Описание |
|--------|----------|
| draft | Чернова |
| planned | Планирана |
| in_progress | В изпълнение |
| completed | Завършена |
| canceled | Отменена |
| on_hold | Задържана |

### Нови полета

- `tech_card_id` - Връзка към технологична карта
- `priority` - Приоритет (1-10, 1 е най-висок)
- `batch_number` - Партиден номер
- `estimated_*_cost` - Планирани разходи
- `actual_*_cost` - Реални разходи

### Работен процес

```
1. Създаване на поръчка от технологична карта
   Manufacturing.create_production_order_from_tech_card(tech_card_id, %{
     tenant_id: 1,
     order_number: "PO-001",
     warehouse_id: 1,
     quantity_to_produce: Decimal.new(100),
     planned_date: ~D[2024-12-15]
   })

2. Стартиране (проверка на наличности, издаване на материали)
   Manufacturing.start_production_order(order)

3. Изпълнение на операции
   Manufacturing.start_operation(operation, operator_id)
   Manufacturing.complete_operation(operation, %{
     actual_setup_time: Decimal.new(15),
     actual_run_time: Decimal.new(120),
     qc_passed: true
   })

4. Завършване (заприходяване на готова продукция, счетоводни записи)
   Manufacturing.complete_production_order(order, quantity_produced, user_id, accounting_settings)
```

## API Endpoints

### Работни центрове
- `GET /work-centers` - Списък
- `GET /work-centers/new` - Нов
- `GET /work-centers/:id/edit` - Редакция

### Технологични карти
- `GET /tech-cards` - Списък
- `GET /tech-cards/new` - Нова
- `GET /tech-cards/:id/edit` - Редакция

### Производствени поръчки
- `GET /production-orders` - Списък
- `GET /production-orders/new` - Нова
- `GET /production-orders/:id/edit` - Редакция

## Миграция от рецепти

Старите рецепти се запазват за обратна съвместимост. За нови проекти се препоръчва използването на технологични карти.

### Разлики

| Рецепти | Технологични карти |
|---------|-------------------|
| Само материали | Материали + Операции |
| Фиксирани количества | Формули и коефициенти |
| Няма версиониране | Версии и валидност |
| Прости разходи | Детайлни разходи |
| Без работни центрове | С работни центрове |

## Примери

### Създаване на пълна технологична карта

```elixir
# 1. Създаване на работни центрове
{:ok, wc_cut} = Manufacturing.create_work_center(%{
  tenant_id: 1,
  code: "CUT-01",
  name: "Машина за рязане",
  center_type: "machine",
  hourly_rate: Decimal.new("30.00")
})

{:ok, wc_assembly} = Manufacturing.create_work_center(%{
  tenant_id: 1,
  code: "ASM-01",
  name: "Монтаж",
  center_type: "workstation",
  hourly_rate: Decimal.new("20.00")
})

# 2. Създаване на технологична карта
materials = [
  %{
    product_id: 1,
    quantity: Decimal.new("2.5"),
    unit: "м",
    coefficient: Decimal.new("1.0"),
    wastage_percent: Decimal.new("5"),
    unit_cost: Decimal.new("15.00")
  },
  %{
    product_id: 2,
    quantity: Decimal.new("4"),
    unit: "бр.",
    coefficient: Decimal.new("1.0"),
    wastage_percent: Decimal.new("0"),
    unit_cost: Decimal.new("2.50"),
    is_fixed: true
  }
]

operations = [
  %{
    work_center_id: wc_cut.id,
    sequence_no: 10,
    name: "Рязане",
    setup_time: Decimal.new("10"),
    run_time_per_unit: Decimal.new("5"),
    labor_rate_per_hour: Decimal.new("20"),
    machine_rate_per_hour: Decimal.new("30")
  },
  %{
    work_center_id: wc_assembly.id,
    sequence_no: 20,
    name: "Монтаж",
    setup_time: Decimal.new("5"),
    run_time_per_unit: Decimal.new("15"),
    labor_rate_per_hour: Decimal.new("18"),
    machine_rate_per_hour: Decimal.new("0"),
    requires_qc: true,
    qc_instructions: "Проверка на размери и здравина"
  }
]

{:ok, tech_card} = Manufacturing.create_tech_card_with_details(
  %{
    tenant_id: 1,
    code: "TC-PRODUCT-001",
    name: "Технологична карта за Продукт A",
    output_product_id: 10,
    output_quantity: Decimal.new("1"),
    output_unit: "бр.",
    version: "1.0",
    overhead_percent: Decimal.new("10")
  },
  materials,
  operations
)
```

## Известни ограничения

1. Формулите не поддържат рекурсия
2. Максимална вложеност на скоби: 10 нива
3. Променливите трябва да съдържат само букви, цифри и долна черта

## Бъдещи подобрения

- [ ] Планиране на капацитет (MRP)
- [ ] Gantt chart за производствени поръчки
- [ ] Интеграция с баркод скенери
- [ ] Мобилно приложение за оператори
- [ ] Автоматично изчисление на цени на продукти
