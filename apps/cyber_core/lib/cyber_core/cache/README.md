# ETS Cache System за CyberERP

Система за кеширане на често използвани данни в ERP системата, базирана на GenServer и ETS таблици.

## Какво е?

ETS (Erlang Term Storage) кеш система, която предоставя:
- **Бързо in-memory кеширане** без външни зависимости
- **Concurrent reads** - множество процеси могат да четат едновременно
- **Event-based invalidation** - автоматично изчистване при промяна на данни
- **Fault tolerance** - интегриран в OTP supervision tree
- **Warm-up при старт** - предварително зареждане на често използвани данни

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                  Application                            │
│  ┌────────────────────────────────────────────────────┐ │
│  │         CyberCore.Cache.Server (GenServer)        │ │
│  │                                                    │ │
│  │  ┌──────────────────────────────────────────────┐ │ │
│  │  │  ETS Tables                                  │ │ │
│  │  │  • :cache_accounts                           │ │ │
│  │  │  • :cache_nomenclatures                      │ │ │
│  │  │  • :cache_measurement_units                  │ │ │
│  │  │  • :cache_vat_rates                          │ │ │
│  │  │  • :cache_settings                           │ │ │
│  │  └──────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                         ▲                               │
│                         │ PubSub Events                 │
│                         │                               │
│  ┌──────────────────────┴─────────────────────────────┐ │
│  │      CyberCore.Cache.Invalidator                  │ │
│  │  (автоматично инвалидиране при промяна)           │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Модули

### 1. CyberCore.Cache.Server
GenServer който управлява ETS таблиците:
- Създава и поддържа ETS таблици
- Warm-up при старт на приложението
- Слуша за invalidation събития чрез PubSub
- Предоставя статистика за използването на кеша

### 2. CyberCore.Cache
Публично API за работа с кеша:
- Удобни функции за достъп до кеширани данни
- Автоматично зареждане от БД при липса в кеша
- Broadcast на invalidation събития

### 3. CyberCore.Cache.Invalidator
Автоматично инвалидиране на кеш при промени:
- Интеграция с Ecto changesets чрез `tap/2`
- Broadcast на invalidation събития
- Поддръжка на Multi транзакции

## Използване

### Основно използване

```elixir
# Взимане на мерна единица по код
{:ok, unit} = CyberCore.Cache.get_measurement_unit_by_code("PCE")

# Взимане на ДДС ставка
{:ok, vat_rate} = CyberCore.Cache.get_vat_rate_by_code("S")

# Взимане на КН код за 2025 година
{:ok, cn_code} = CyberCore.Cache.get_cn_code("01012100", 2025)

# Взимане на сметка по код
{:ok, account} = CyberCore.Cache.get_account_by_code("411")

# Списък с всички мерни единици (кеширани)
units = CyberCore.Cache.list_measurement_units()
```

### Инвалидиране на кеш

```elixir
# Инвалидиране на конкретна таблица
CyberCore.Cache.invalidate_measurement_units()
CyberCore.Cache.invalidate_vat_rates()
CyberCore.Cache.invalidate_accounts()

# Инвалидиране на всичко
CyberCore.Cache.invalidate_all()

# Презареждане на таблица от БД
CyberCore.Cache.reload(:cache_measurement_units)
```

### Статистика

```elixir
# Връща статистика за всички таблици
stats = CyberCore.Cache.stats()
# => %{
#   cache_measurement_units: %{size: 30, memory: 5240},
#   cache_vat_rates: %{size: 5, memory: 1024},
#   hits: 1250,
#   misses: 42,
#   hit_rate: 96.7
# }

# Health check
CyberCore.Cache.health_check()
# => %{status: :healthy, stats: ...}
```

## Интеграция в контексти

Автоматичното инвалидиране се случва в контекстите при CRUD операции:

```elixir
# apps/cyber_core/lib/cyber_core/inventory.ex

def create_measurement_unit(attrs) do
  %MeasurementUnit{}
  |> MeasurementUnit.changeset(attrs)
  |> Repo.insert()
  |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_unit/1)
end

def update_measurement_unit(%MeasurementUnit{} = unit, attrs) do
  unit
  |> MeasurementUnit.changeset(attrs)
  |> Repo.update()
  |> tap(&CyberCore.Cache.Invalidator.invalidate_measurement_unit/1)
end
```

## Кеширани данни

### 1. Measurement Units (Мерни единици)
- **Таблица**: `:cache_measurement_units`
- **Ключове**:
  - `id` - по ID
  - `"code:#{code}"` - по код (напр. "code:PCE")
- **Warm-up**: Всички мерни единици при старт

### 2. VAT Rates (ДДС ставки)
- **Таблица**: `:cache_vat_rates`
- **Ключове**:
  - `id` - по ID
  - `"code:#{code}"` - по код (напр. "code:S")
- **Warm-up**: Всички активни ДДС ставки при старт

### 3. CN Nomenclature (КН номенклатура)
- **Таблица**: `:cache_nomenclatures`
- **Ключове**:
  - `id` - по ID
  - `"cn:#{year}:#{code}"` - по код и година (напр. "cn:2025:01012100")
- **Warm-up**: Топ 100 най-нови КН кода при старт

### 4. Accounts (Сметкоплан)
- **Таблица**: `:cache_accounts`
- **Ключове**:
  - `id` - по ID
  - `"code:#{code}"` - по код (напр. "code:411")
- **Warm-up**: Не се зарежда автоматично (lazy loading)

### 5. Settings (Настройки)
- **Таблица**: `:cache_settings`
- **Ключове**: Произволни ключове
- **Warm-up**: Не се зарежда автоматично

## Event-based Invalidation

Системата използва Phoenix.PubSub за автоматично инвалидиране:

### События

- `{:invalidate, table, key}` - Инвалидира конкретен запис
- `{:invalidate_table, table}` - Инвалидира цяла таблица
- `{:invalidate_all}` - Инвалидира всички таблици

### PubSub Topics

- `"cache:invalidate"` - Основен topic за invalidation събития
- `"cache:events"` - События за промени (за monitoring)

### Broadcast функции

```elixir
# В Invalidator модула
defp broadcast(event, payload) do
  Phoenix.PubSub.broadcast(
    CyberCore.PubSub,
    "cache:events",
    {event, payload}
  )
end
```

## Performance съображения

### Concurrent reads
ETS таблиците са конфигурирани с `read_concurrency: true`, което позволява множество процеси да четат едновременно без блокиране.

### Memory
Всяка ETS таблица съхранява данните в паметта. Използвайте `stats()` за мониторинг на паметта.

### Warm-up strategy
При старт на приложението, системата зарежда:
- Всички мерни единици (~30 записа)
- Всички ДДС ставки (~5-10 записа)
- Топ 100 КН кода

Останалите данни се зареждат lazy при първо извикване.

## Бъдещи подобрения

- [ ] TTL (Time-to-Live) за автоматично изтичане на кеш
- [ ] LRU (Least Recently Used) евакуация при достигане на лимит
- [ ] Персистентност на кеш между рестарти (optional)
- [ ] Metrics и мониторинг интеграция
- [ ] Distributed cache за multi-node setup

## Сравнение с Redis

| Критерий | ETS Cache | Redis |
|----------|-----------|-------|
| **Setup** | Вграден в Elixir | Изисква външен процес |
| **Latency** | < 1μs | 1-5ms (network) |
| **Concurrency** | Native BEAM | Network bottleneck |
| **Persistence** | Не (in-memory) | Да (optional) |
| **Distributed** | Не (single node) | Да (native) |
| **Подходящо за** | ERP справочни данни | Multi-node, sessions |

## Заключение

ETS кеш системата е идеална за:
- Справочни данни (номенклатури, мерни единици, сметкоплан)
- Често четени, рядко променяни данни
- Single-node или small-cluster deployments
- Ниска latency изисквания

За distributed кеш или персистентност, може да се разгледа Redis или Mnesia.
