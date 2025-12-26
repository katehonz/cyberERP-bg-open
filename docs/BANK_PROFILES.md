# Bank Profiles (Банкови профили)

## Общ преглед

Системата за банкови профили предоставя функционалност за управление на банкови сметки с две основни възможности:
- **Автоматична синхронизация** чрез Salt Edge API
- **Ръчен импорт** на файлове (MT940, CAMT.053, CSV, XML)

## Функционалност

### 1. Банков профил

Всеки банков профил представлява конфигурация на една банкова сметка и включва:

```elixir
schema "bank_profiles" do
  field :name, :string              # Име на профила
  field :iban, :string              # IBAN номер
  field :bic, :string               # BIC/SWIFT код
  field :bank_name, :string         # Име на банката
  field :currency_code, :string     # Валута (BGN, EUR, USD)
  field :import_format, :string     # Формат за импорт
  field :auto_sync_enabled, :boolean # Автоматична синхронизация
  field :saltedge_connection_id, :string
  field :saltedge_account_id, :string
  field :last_synced_at, :naive_datetime

  belongs_to :tenant, Tenant
  belongs_to :bank_account, Account        # Счетоводна сметка (напр. 102)
  belongs_to :buffer_account, Account      # Буферна сметка за сверка

  has_one :bank_connection, BankConnection
  has_many :bank_imports, BankImport
  has_many :bank_transactions, BankTransaction
end
```

### 2. Формати за импорт

Системата поддържа следните формати:

| Формат | Тип | Банки | Описание |
|--------|-----|-------|----------|
| **MT940** | SWIFT | Всички международни | Стандартен SWIFT формат |
| **CAMT.053 (Wise)** | XML | Wise | ISO 20022 формат за Wise |
| **CAMT.053 (Revolut)** | XML | Revolut | ISO 20022 формат за Revolut |
| **CAMT.053 (Paysera)** | XML | Paysera | ISO 20022 формат за Paysera |
| **ЦКБ CSV** | CSV | ЦКБ | CSV експорт от ЦКБ |
| **Пощенска банка XML** | XML | Пощенска банка | Proprietary XML формат |
| **ОББ XML** | XML | ОББ | Proprietary XML формат |

### 3. Salt Edge интеграция

#### Как работи?

```
┌──────────────────────────────────────────────────────────────────┐
│                        Cyber ERP                                  │
│  ┌────────────────────────────────────────────────────────┐      │
│  │              BankProfile                                │      │
│  │  - saltedge_connection_id                              │      │
│  │  - auto_sync_enabled: true                             │      │
│  └────────────────┬───────────────────────────────────────┘      │
│                   │                                               │
│                   │ (scheduled job every 4 hours)                 │
│                   ▼                                               │
│  ┌────────────────────────────────────────────────────────┐      │
│  │         SyncScheduler.perform_sync/0                    │      │
│  │  1. Намери всички активни профили                      │      │
│  │  2. За всеки профил викай Salt Edge API                │      │
│  │  3. Запази транзакциите в DB                           │      │
│  └────────────────┬───────────────────────────────────────┘      │
└────────────────────┼──────────────────────────────────────────────┘
                     │
                     │ HTTP Request
                     ▼
┌──────────────────────────────────────────────────────────────────┐
│                     Salt Edge API                                 │
│  GET /api/v5/transactions                                         │
│  - connection_id: "abc123"                                        │
│  - account_id: "xyz789"                                           │
│  - from_date: last_synced_at                                      │
│                                                                   │
│  Response:                                                        │
│  {                                                                │
│    "data": [                                                      │
│      {                                                            │
│        "id": "trans_123",                                         │
│        "amount": "-50.00",                                        │
│        "currency_code": "BGN",                                    │
│        "description": "Transfer to John",                         │
│        "made_on": "2025-11-22"                                    │
│      }                                                            │
│    ]                                                              │
│  }                                                                │
└──────────────────────────────────────────────────────────────────┘
```

#### Настройка на Salt Edge връзка:

1. Създай профил в Cyber ERP
2. Получи redirect URL от Salt Edge
3. Потребителят се логва в банката си
4. Salt Edge връща `connection_id` и `account_id`
5. Запази ги в профила
6. Автоматичната синхронизация стартира на всеки 4 часа

### 4. Ръчен импорт

#### Работен процес:

1. Потребителят изтегля файл от банката (напр. MT940)
2. Отива на `/bank-imports` и качва файла
3. Системата:
   - Разпознава формата на файла
   - Парсва транзакциите
   - Проверява дубликати
   - Запазва транзакциите
   - Създава счетоводни записи (опционално)

#### Парсери:

Всеки парсер е модул в `apps/cyber_core/lib/cyber_core/bank/parsers/`:

```elixir
defmodule CyberCore.Bank.Parsers.MT940 do
  def parse(content) do
    # Парсва MT940 формат
    # Връща {:ok, transactions} или {:error, reason}
  end
end
```

**Налични парсери:**
- `MT940.ex` - SWIFT MT940 стандарт
- `CAMT053.ex` - ISO 20022 XML формат
- `CCBCsv.ex` - ЦКБ CSV формат
- `PostbankXml.ex` - Пощенска банка XML
- `OBBXml.ex` - ОББ XML

### 5. Валидация

#### IBAN валидация (`apps/cyber_core/lib/cyber_core/bank/validators/iban.ex`)

```elixir
def validate(iban) do
  # 1. Премахва интервали
  # 2. Проверява дължина (15-34 символа)
  # 3. Проверява формат (2 букви + 2 цифри + останало)
  # 4. Модул 97 проверка (ISO 13616)
  {:ok, normalized_iban} или {:error, reason}
end
```

#### BIC валидация (`apps/cyber_core/lib/cyber_core/bank/validators/bic.ex`)

```elixir
def validate(bic) do
  # 1. Проверява дължина (8 или 11 символа)
  # 2. Проверява формат (AAAA BB CC [DDD])
  #    - AAAA: код на банката
  #    - BB: код на държавата
  #    - CC: локация
  #    - DDD: клон (опционално)
  {:ok, normalized_bic} или {:error, reason}
end
```

## UI компоненти

### 1. Индекс страница (`/bank-profiles`)

**Функции:**
- Показва всички банкови профили в card layout
- Статус индикатори:
  - 🟢 Автоматична синхронизация (зелен badge)
  - ⚪ Ръчен импорт (сив badge)
  - 🔗 Salt Edge връзка (активна/изисква повторна връзка)
- Действия:
  - 🔄 Синхронизирай сега (за Salt Edge профили)
  - 📋 Импорти
  - 💳 Транзакции
  - ✏️ Редактирай
  - 🗑️ Изтрий

**Код:**
```heex
<div class="grid gap-6">
  <%= for profile <- @bank_profiles do %>
    <div class="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div class="border-b border-zinc-200 bg-zinc-50 px-6 py-4">
        <h3><%= profile.name %></h3>
        <p><%= profile.iban %> • <%= profile.bank_name %></p>

        <%= if profile.auto_sync_enabled do %>
          <span class="bg-green-100 text-green-800">
            🟢 Автоматична синхронизация
          </span>
        <% end %>
      </div>

      <div class="px-6 py-4">
        <!-- Детайли: валута, сметки, формат, последна синхронизация -->
      </div>
    </div>
  <% end %>
</div>
```

### 2. Форма компонент (`/bank-profiles/new`, `/bank-profiles/:id/edit`)

**Полета:**
- **Име** - Идентификация на профила
- **IBAN** - Банкова сметка (с валидация)
- **BIC/SWIFT** - Банков идентификатор (с валидация)
- **Име на банката** - Текстово поле
- **Банкова сметка (счетоводство)** - Dropdown с всички сметки (напр. 102 - Разплащателна сметка)
- **Буферна сметка (за сверка)** - Dropdown с всички сметки
- **Валута** - BGN, EUR, USD, etc.
- **Формат за ръчен импорт** - Dropdown с 7 формата
- **Автоматична синхронизация** - Checkbox (Salt Edge)

**Validation:**
```elixir
def changeset(bank_profile, attrs) do
  bank_profile
  |> cast(attrs, [:name, :iban, :bic, ...])
  |> validate_required([:name, :bank_account_id, :buffer_account_id, :currency_code])
  |> validate_iban()
  |> validate_bic()
end
```

## Схема на базата данни

### Таблици:

#### `bank_profiles`
- Конфигурация на банкови сметки
- Връзка към счетоводни сметки
- Salt Edge настройки

#### `bank_connections`
- Salt Edge connection метаданни
- Статус на връзката
- Credentials и токени

#### `bank_imports`
- История на импортирани файлове
- Метаданни (файл, формат, брой транзакции)
- Статус (processing, completed, failed)

#### `bank_transactions`
- Индивидуални транзакции
- Връзка към bank_profile и bank_import
- Връзка към счетоводни записи (journal_entries)
- Reconciliation статус

**ER диаграма:**
```
┌─────────────────┐
│  bank_profiles  │
├─────────────────┤
│ id              │───┐
│ tenant_id       │   │
│ bank_account_id │   │
│ buffer_acc_id   │   │
│ iban            │   │
│ bic             │   │
│ ...             │   │
└─────────────────┘   │
                      │ 1:1
                      ▼
           ┌──────────────────────┐
           │  bank_connections    │
           ├──────────────────────┤
           │ id                   │
           │ bank_profile_id      │
           │ saltedge_conn_id     │
           │ status               │
           │ ...                  │
           └──────────────────────┘
                      │ 1:N
                      ▼
           ┌──────────────────────┐
           │   bank_imports       │
           ├──────────────────────┤
           │ id                   │
           │ bank_profile_id      │
           │ file_name            │
           │ format               │
           │ ...                  │
           └──────────────────────┘
                      │ 1:N
                      ▼
           ┌──────────────────────┐
           │  bank_transactions   │
           ├──────────────────────┤
           │ id                   │
           │ bank_profile_id      │
           │ bank_import_id       │
           │ amount               │
           │ description          │
           │ transaction_date     │
           │ reconciled           │
           │ journal_entry_id     │
           │ ...                  │
           └──────────────────────┘
```

## Автоматична синхронизация

### SyncScheduler (`apps/cyber_core/lib/cyber_core/bank/sync_scheduler.ex`)

GenServer който се стартира автоматично при зареждане на апликацията.

```elixir
defmodule CyberCore.Bank.SyncScheduler do
  use GenServer

  @sync_interval :timer.hours(4)  # Синхронизация на всеки 4 часа

  def init(_) do
    schedule_sync()
    {:ok, %{}}
  end

  def handle_info(:perform_sync, state) do
    perform_sync()
    schedule_sync()
    {:noreply, state}
  end

  defp perform_sync do
    BankProfile
    |> where([p], p.is_active == true)
    |> where([p], p.auto_sync_enabled == true)
    |> where([p], not is_nil(p.saltedge_connection_id))
    |> Repo.all()
    |> Enum.each(&BankService.sync_saltedge_transactions/1)
  end
end
```

**Стартира се автоматично в:**
```elixir
# apps/cyber_core/lib/cyber_core/application.ex
def start(_type, _args) do
  children = [
    # ...
    CyberCore.Bank.SyncScheduler,  # <-- Тук
    # ...
  ]
end
```

## Файлове

### Backend

**Core:**
- `apps/cyber_core/lib/cyber_core/bank/bank_profile.ex` - Schema
- `apps/cyber_core/lib/cyber_core/bank/bank_connection.ex` - Salt Edge връзка
- `apps/cyber_core/lib/cyber_core/bank/bank_import.ex` - Импорт история
- `apps/cyber_core/lib/cyber_core/bank/bank_transaction.ex` - Транзакции

**Services:**
- `apps/cyber_core/lib/cyber_core/bank/bank_service.ex` - Бизнес логика
- `apps/cyber_core/lib/cyber_core/bank/salt_edge_client.ex` - Salt Edge API клиент
- `apps/cyber_core/lib/cyber_core/bank/sync_scheduler.ex` - Автоматична синхронизация

**Parsers:**
- `apps/cyber_core/lib/cyber_core/bank/parsers/mt940.ex`
- `apps/cyber_core/lib/cyber_core/bank/parsers/camt053.ex`
- `apps/cyber_core/lib/cyber_core/bank/parsers/ccb_csv.ex`
- `apps/cyber_core/lib/cyber_core/bank/parsers/postbank_xml.ex`
- `apps/cyber_core/lib/cyber_core/bank/parsers/obb_xml.ex`

**Validators:**
- `apps/cyber_core/lib/cyber_core/bank/validators/iban.ex`
- `apps/cyber_core/lib/cyber_core/bank/validators/bic.ex`

### Frontend

**LiveView:**
- `apps/cyber_web/lib/cyber_web/live/bank_profile_live/index.ex` - Индекс страница
- `apps/cyber_web/lib/cyber_web/live/bank_profile_live/index.html.heex` - UI template
- `apps/cyber_web/lib/cyber_web/live/bank_profile_live/form_component.ex` - Форма компонент

**Routes:**
```elixir
# apps/cyber_web/lib/cyber_web/router.ex
live "/bank-profiles", BankProfileLive.Index, :index
live "/bank-profiles/new", BankProfileLive.Index, :new
live "/bank-profiles/:id/edit", BankProfileLive.Index, :edit
```

### Database

**Migrations:**
- `apps/cyber_core/priv/repo/migrations/20251122120028_create_bank_tables.exs`

## Тестване

### Test 1: Създаване на профил за ръчен импорт

1. Отиди на `/bank-profiles`
2. Кликни "Нов профил"
3. Попълни:
   - Име: "ЦКБ - Основна сметка"
   - IBAN: "BG80CECB97901234567890"
   - Банкова сметка: "102 - Разплащателна сметка"
   - Буферна сметка: "551 - Временни сметки"
   - Валута: "BGN"
   - Формат: "ЦКБ CSV"
4. Запази
5. ✅ Профилът се създава успешно

### Test 2: Автоматична синхронизация

1. Създай профил с `auto_sync_enabled: true`
2. Конфигурирай Salt Edge connection
3. Изчакай 4 часа или рестартирай scheduler
4. ✅ Транзакциите се синхронизират автоматично

### Test 3: Ръчна синхронизация

1. Отвори профил със Salt Edge connection
2. Кликни "🔄 Синхронизирай сега"
3. ✅ Нови транзакции се импортират незабавно

## Security (Сигурност)

### API Keys
- Salt Edge API ключове се съхраняват в `config/runtime.exs`
- Никога не се commit-ват в git
- Използват се environment variables

```elixir
config :cyber_core, :salt_edge,
  app_id: System.get_env("SALT_EDGE_APP_ID"),
  secret: System.get_env("SALT_EDGE_SECRET")
```

### IBAN/BIC маскиране
- В UI се показват само последните 4 цифри: `BG80 CECB **** **** **90`
- Пълният IBAN е видим само за администратори

### Tenant isolation
- Всички заявки филтрират по `tenant_id`
- Невъзможно е да се видят профили от други фирми

## Roadmap

### Планирани функции:
- [ ] Автоматично създаване на счетоводни записи при импорт
- [ ] Rules engine за автоматично категоризиране на транзакции
- [ ] Reconciliation интерфейс (сверка с контрагенти)
- [ ] Multi-currency support с автоматична конверсия
- [ ] Reporting и анализи на паричния поток
- [ ] Webhook интеграция със Salt Edge за real-time updates
- [ ] OCR за сканиране на банкови извлечения
