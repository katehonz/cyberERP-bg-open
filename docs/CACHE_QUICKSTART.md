# ETS Cache System - Quick Start

## Какво е това?

ETS (Erlang Term Storage) кеш система за бързо кеширане на често използвани данни в CyberERP без нужда от Redis или други външни зависимости.

## Стартиране

Кеш системата стартира автоматично с приложението. Няма нужда от допълнителна конфигурация.

```bash
# Стартирайте приложението
iex -S mix

# Ще видите в логовете:
# [info] Cache.Server started with tables: [:cache_accounts, :cache_nomenclatures, ...]
# [info] Starting cache warm-up...
```

## Бързи примери

### 1. Основно използване

```elixir
alias CyberCore.Cache

# Взимане на мерна единица
{:ok, unit} = Cache.get_measurement_unit_by_code("PCE")

# Взимане на ДДС ставка
{:ok, vat_rate} = Cache.get_vat_rate_by_code("S")

# Взимане на КН код
{:ok, cn_code} = Cache.get_cn_code("01012100", 2025)

# Взимане на сметка
{:ok, account} = Cache.get_account_by_code("411")
```

### 2. Листване на данни

```elixir
# Всички мерни единици (кеширани)
units = Cache.list_measurement_units()

# Всички ДДС ставки (кеширани)
vat_rates = Cache.list_vat_rates()
```

### 3. Търсене

```elixir
# Търсене на КН кодове по префикс
cn_codes = Cache.search_cn_codes("0101", 2025, limit: 20)
```

### 4. Статистика

```elixir
# Статистика за кеша
Cache.stats()
# => %{
#   cache_measurement_units: %{size: 30, memory: 5240},
#   hits: 1250,
#   misses: 42,
#   hit_rate: 96.7
# }

# Health check
Cache.health_check()
# => %{status: :healthy, stats: ...}
```

### 5. Инвалидиране (ако е нужно)

```elixir
# Инвалидиране на конкретна таблица
Cache.invalidate_measurement_units()
Cache.invalidate_vat_rates()

# Инвалидиране на всичко
Cache.invalidate_all()

# Презареждане от БД
Cache.reload(:cache_measurement_units)
```

## Тестване

Изпълнете примерния файл:

```bash
mix run apps/cyber_core/lib/cyber_core/cache/examples.exs
```

## Автоматично инвалидиране

Кешът се инвалидира автоматично при промяна на данни:

```elixir
# При създаване на мерна единица
Inventory.create_measurement_unit(%{code: "TST", name: "Test"})
# Кешът се инвалидира автоматично!

# При обновяване на ДДС ставка
Accounting.update_vat_rate(rate, %{rate: 21})
# Кешът се инвалидира автоматично!
```

## Какво се кешира?

| Данни | Warm-up при старт | Invalidation |
|-------|-------------------|--------------|
| Мерни единици | ✓ Всички | Автоматично |
| ДДС ставки | ✓ Всички | Автоматично |
| КН кодове | ✓ Топ 100 | Автоматично |
| Сметкоплан | ✗ Lazy loading | Автоматично |
| Настройки | ✗ Lazy loading | Ръчно |

## Performance

- **Latency**: < 1μs (vs 1-5ms за Redis)
- **Concurrency**: Native BEAM concurrent reads
- **Memory**: In-memory, мониторинг чрез `Cache.stats()`

## Документация

Пълна документация: `apps/cyber_core/lib/cyber_core/cache/README.md`

## Често задавани въпроси

### Трябва ли ми Redis?

**Не**, ако:
- Имате single-node или малък cluster
- Кеширате справочни данни (номенклатури, настройки)
- Не ви трябва персистентност на кеша между рестарти

**Да**, ако:
- Имате distributed multi-node setup
- Ви трябва персистентност
- Имате много големи данни (> 1GB кеш)

### Какво се случва при рестарт?

ETS таблиците са in-memory и се изчистват при рестарт. При старт на приложението има warm-up период, където често използваните данни се зареждат автоматично.

### Как да добавя нови данни за кеширане?

1. Добавете нова ETS таблица в `Cache.Server`
2. Създайте функции в `Cache` модула
3. Добавете invalidation логика в `Cache.Invalidator`
4. Добавете warm-up в `Cache.Server.warm_up/0` (optional)

### Мога ли да изключа кеша?

Да, просто премахнете `CyberCore.Cache.Server` от supervision tree в `application.ex`.

## Поддръжка

За въпроси или проблеми, вижте:
- Документация: `apps/cyber_core/lib/cyber_core/cache/README.md`
- Примери: `apps/cyber_core/lib/cyber_core/cache/examples.exs`
