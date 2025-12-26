# Модул за Дълготрайни Материални Активи (ДМА)

Пълнофункционален модул за управление на дълготрайни активи, отговарящ на българските счетоводни стандарти и изискванията на ЗКПО (Закон за корпоративното подоходно облагане).

## Основни Функционалности

### 1. Управление на Активи

#### Създаване и регистрация
- Пълна информация за актива (код, наименование, категория)
- Инвентарен и сериен номер
- Местонахождение и материално отговорно лице
- Информация за доставчик и фактура за придобиване

#### Данъчни Категории според ЗКПО

Модулът поддържа 7-те официални данъчни категории:

| Категория | Описание | Норма на амортизация |
|-----------|----------|---------------------|
| **I** | Сгради, съоръжения, мрежи | 4% годишно |
| **II** | Машини, производствено оборудване | 30% годишно |
| **III** | Транспортни средства (без автомобили) | 10% годишно |
| **IV** | Компютри, софтуер, мобилни телефони | 50% годишно |
| **V** | Автомобили | 25% годишно |
| **VI** | Активи с договорно ограничен срок | По договор (макс. 33.33%) |
| **VII** | Всички други активи | 15% годишно |

### 2. Счетоводни Сметки

Модулът интегрира с българския счетоплан:

- **203** - Компютърна техника (и други подсметки на група 20 - ДМА)
- **2413** - Амортизация на дълготрайни активи (буферна сметка)
- **603** - Разходи за амортизация

### 3. Амортизация

#### Методи на амортизация:
- **Линеен метод** (straight_line) - най-често използван
- **Намаляващ метод** (declining_balance)
- **По единици продукция** (units_of_production)

#### Двойна амортизация:
- **Счетоводна амортизация** - за финансови отчети
- **Данъчна амортизация** - според ЗКПО
- Възможност за различни норми и методи

#### Автоматично генериране на график
- Месечни записи за амортизация
- Изчисляване на натрупана амортизация
- Проследяване на балансова стойност
- Статуси: планиран, постнат, пропуснат

### 4. Счетоводни Записи

#### Амортизация (автоматично генериране):
```
Дт 603 (Разходи за амортизация)     XXX.XX
Кт 2413 (Амортизация на ДМА)              XXX.XX
```

#### Извеждане от употреба:
```
Дт 2413 (Амортизация)               XXX.XX
Кт 203 (ДМА)                              XXX.XX
+ Печалба/Загуба при разлика
```

### 5. Статуси на Активи

- **active** - Активен актив
- **inactive** - Временно неактивен
- **disposed** - Изведен от употреба
- **fully_depreciated** - Напълно амортизиран

## Database Schema

### Assets Table
```sql
- id, tenant_id
- code, name, category
- inventory_number, serial_number
- location, responsible_person
- tax_category, tax_depreciation_rate, accounting_depreciation_rate
- acquisition_date, acquisition_cost
- supplier_id, invoice_number, invoice_date
- salvage_value, useful_life_months, depreciation_method
- status, residual_value
- accounting_account_id, expense_account_id, accumulated_depreciation_account_id
- disposal_date, disposal_reason, disposal_value, disposal_journal_entry_id
- notes, attachments, metadata
```

### Asset Depreciation Schedules Table
```sql
- id, tenant_id, asset_id, journal_entry_id
- period_date, amount, status
- depreciation_type (accounting/tax)
- accounting_amount, tax_amount
- accumulated_depreciation, book_value
```

## API / Context Functions

### CyberCore.Accounting.FixedAssets

#### CRUD операции:
```elixir
# List assets
list_assets(tenant_id, opts \\ [])

# Get asset
get_asset!(tenant_id, id, preloads \\ [])

# Create asset
create_asset(attrs)
create_asset_with_schedule(attrs, opts \\ [])

# Update asset
update_asset(asset, attrs)

# Delete asset
delete_asset(asset)
```

#### Амортизация:
```elixir
# Generate depreciation schedule
generate_depreciation_schedule(asset, opts \\ [])

# List schedule
list_depreciation_schedule(asset_id)

# Pending depreciation for period
list_pending_depreciation(tenant_id, period_date)

# Post depreciation
post_depreciation(schedule)
post_period_depreciation(tenant_id, period_date)
```

#### Изчисления:
```elixir
# Calculate accumulated depreciation
calculate_accumulated_depreciation(asset)

# Calculate book value
calculate_book_value(asset)

# Get statistics
get_assets_statistics(tenant_id)
```

#### Извеждане от употреба:
```elixir
dispose_asset(asset, disposal_attrs)
```

### CyberCore.Accounting.Asset Schema

```elixir
# Get tax categories
Asset.tax_categories()

# Get category info
Asset.tax_category_info("IV")
# => %{name: "Компютри и софтуер", rate: 0.50}

# Calculate depreciation
Asset.calculate_annual_depreciation(asset, :accounting)
Asset.calculate_monthly_depreciation(asset, :tax)

# Status checks
Asset.fully_depreciated?(asset)
Asset.disposed?(asset)
```

## Routes

```
GET  /fixed-assets              - List all assets
GET  /fixed-assets/new          - New asset form
GET  /fixed-assets/:id/edit     - Edit asset form
GET  /fixed-assets/:id/schedule - View depreciation schedule
```

## LiveView Components

1. **FixedAssetLive.Index** - Main listing with filters and statistics
2. **FixedAssetLive.FormComponent** - Create/Edit form
3. **FixedAssetLive.ScheduleComponent** - Depreciation schedule viewer

## Usage Examples

### Създаване на актив - Компютър

```elixir
alias CyberCore.Accounting.FixedAssets

attrs = %{
  tenant_id: 1,
  code: "DMA-001",
  name: "Лаптоп Dell Latitude 5420",
  category: "computer",
  inventory_number: "INV-2025-001",
  tax_category: "IV",  # Автоматично 50% годишна амортизация
  acquisition_date: ~D[2025-01-15],
  acquisition_cost: Decimal.new("2400.00"),
  useful_life_months: 36,
  depreciation_method: "straight_line",
  supplier_id: 123,
  invoice_number: "INV-2025-0042",
  invoice_date: ~D[2025-01-15],
  location: "Офис София",
  responsible_person: "Иван Иванов"
}

# Създаване с автоматичен график
{:ok, asset} = FixedAssets.create_asset_with_schedule(attrs)

# Ще се генерират 36 месечни записа за амортизация
# Месечна амортизация: 2400 * 0.50 / 12 = 100 лв/месец
```

### Постване на месечна амортизация

```elixir
# Постване на амортизацията за януари 2025
{:ok, count} = FixedAssets.post_period_depreciation(1, ~D[2025-01-31])
# => {:ok, 15}  # 15 активa амортизирани

# Автоматично създадени счетоводни записи:
# Дт 603   100.00
# Кт 2413  100.00
```

### Извеждане от употреба

```elixir
asset = FixedAssets.get_asset!(1, 42)

disposal_attrs = %{
  disposal_date: ~D[2025-06-30],
  disposal_reason: "Физическа амортизация",
  disposal_value: Decimal.new("500.00")
}

{:ok, disposed_asset} = FixedAssets.dispose_asset(asset, disposal_attrs)
```

### Статистика

```elixir
stats = FixedAssets.get_assets_statistics(1)

# => %{
#   total_count: 127,
#   active_count: 98,
#   disposed_count: 12,
#   total_acquisition_cost: Decimal.new("450000.00"),
#   total_accumulated_depreciation: Decimal.new("185000.00"),
#   total_book_value: Decimal.new("265000.00")
# }
```

## Бизнес Логика

### Валидации

- Задължителни полета: код, име, категория, дата и стойност на придобиване
- Уникален код и инвентарен номер в рамките на tenant
- Стойността трябва да е >= 700 лв (праг на същественост според ЗКПО)
- Валидни данъчни категории I-VII
- Положителни стойности за суми
- Норми на амортизация 0-100%

### Автоматизация

- **Автоматично задаване на данъчна норма** според категория
- **Генериране на график** за целия полезен живот
- **Изчисляване на натрупана амортизация** и балансова стойност
- **Автоматични счетоводни записи** при постване

### Гъвкавост

- Различни норми за счетоводна и данъчна амортизация
- Възможност за ръчна промяна на норми
- Поддръжка на 3 метода на амортизация
- Проследяване на цял жизнен цикъл

## Отчети и Справки

Модулът предоставя данни за:

1. **Списък на активите** - с филтри по статус и категория
2. **График за амортизация** - по актив или общ
3. **Статистика** - общи показатели
4. **Регистър на ДМА** - изискван от счетоводния стандарт
5. **Данъчни справки** - за годишната данъчна декларация

## Интеграция

Модулът е напълно интегриран с:

- ✅ **Сметкоплан** (Accounting.Account)
- ✅ **Счетоводни записи** (Accounting.JournalEntry)
- ✅ **Контрагенти** (Contacts.Contact) за доставчици
- ✅ **Multi-tenancy** система
- ✅ **VAT модул** (за ДДС при придобиване)

## Съответствие със Стандарти

- ✅ Български счетоводен стандарт (БСС)
- ✅ ЗКПО - чл. 50 (Данъчно амортизируеми активи)
- ✅ НАП изисквания за регистри
- ✅ SAF-T стандарт (бъдеща интеграция)

## Миграции

За да активирате модула, изпълнете:

```bash
mix ecto.migrate
```

Миграцията добавя:
- Нови полета в `assets` таблица
- Нови полета в `asset_depreciation_schedules` таблица
- Индекси за оптимизация
- Foreign keys към contacts и accounts

## Развитие

Планирани подобрения:

- [ ] Импорт от Excel
- [ ] Експорт в Excel/PDF
- [ ] Баркод/QR код етикети
- [ ] Снимки и прикачени файлове
- [ ] Одит и история на промените
- [ ] Масова инвентаризация
- [ ] Интеграция с IoT устройства
- [ ] Прогнозна амортизация

## Разработчик

Модулът е създаден на 18.11.2025 като част от cyber_ERP системата.

**Файлове:**
- `apps/cyber_core/lib/cyber_core/accounting/asset.ex`
- `apps/cyber_core/lib/cyber_core/accounting/asset_depreciation_schedule.ex`
- `apps/cyber_core/lib/cyber_core/accounting/fixed_assets.ex`
- `apps/cyber_web/lib/cyber_web/live/fixed_asset_live/`
- Migration: `20251118211038_enhance_fixed_assets_module.exs`
