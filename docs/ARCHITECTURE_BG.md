# Архитектура на Cyber ERP

## План за рефакторинг и развитие

Основната цел на архитектурния план е да осигури стабилна основа за бързо развитие в краткосрочен план, като същевременно поддържа гъвкавост за бъдещо разширяване и преминаване към по-сложни модели като микросервизи, ако и когато това стане необходимо.

Стратегията е базирана на архитектурата **Модулен монолит**. Този подход е избран, за да се балансира между скоростта на разработка и поддържането на ясни граници между различните функционални домейни на системата (счетоводство, продажби, склад и др.).

### Пътят напред: 3 фази

Планът за развитие е разделен на три основни фази, които позволяват постепенна еволюция на системата:

1.  **Фаза 1 (Текуща): Модулен монолит**
    *   Всички функционални домейни (контексти) се намират в един-единствен процес (Umbrella приложение).
    *   Споделена база данни (PostgreSQL), което гарантира ACID транзакции и консистентност на данните в реално време.
    *   **Предимства:** Бърза разработка, лесен deployment, нисък operational overhead.

2.  **Фаза 2 (Бъдеще, при необходимост): Хибриден модел**
    *   Ключови модули остават в монолитното ядро.
    *   Специфични, тежки или ресурсоемки процеси могат да бъдат изнесени в отделни микросервизи.
    *   **Примери:**
        *   `Document Processing (AI)`: Модулът за обработка на документи с AI, който е CPU/IO интензивен, може да стане отделен сървис, за да се скалира независимо.
        *   `Bank Import`: Модулът за импорт на банкови извлечения, който е IO-bound, също е кандидат за отделяне.

3.  **Фаза 3 (Далечно бъдеще, при екстремен растеж): Пълни микросервизи**
    *   Всеки контекст (Accounting, Sales, Inventory) се превръща в напълно независим микросервиз със собствена база данни.
    *   Комуникацията между сървисите се осъществява през асинхронни събития (message queue) и REST/gRPC API-та.
    *   Това е най-сложният модел, който ще бъде внедрен само ако мащабът на системата и размерът на екипа го налагат.

Този поетапен подход ни позволява да се възползваме от предимствата на монолитната архитектура в началото, като същевременно имаме ясен и дефиниран път за справяне с бъдещи предизвикателства, свързани със скалируемостта.

---

## Общ преглед

Cyber ERP е модерна, мащабируема ERP система, изградена на Elixir/Phoenix с фокус върху българския пазар.

## Модулен монолит: Защо не микросервизи?

### Какво е "Модулен монолит"?

Cyber ERP използва архитектурата **Modular Monolith** (Модулен монолит) - това е средно решение между класическия монолит и микросервизите:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cyber ERP (Модулен монолит)                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │ Accounting│  │  Sales    │  │ Inventory │  │   Bank    │    │
│  │  Context  │  │  Context  │  │  Context  │  │  Context  │    │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘    │
│        │              │              │              │           │
│        └──────────────┴──────────────┴──────────────┘           │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │   Shared Kernel    │                        │
│                    │  (Repo, PubSub)    │                        │
│                    └───────────────────┘                        │
├─────────────────────────────────────────────────────────────────┤
│                       PostgreSQL Database                        │
└─────────────────────────────────────────────────────────────────┘
```

### Сравнение на архитектури

| Характеристика | Класически монолит | **Модулен монолит** | Микросервизи |
|----------------|--------------------|--------------------|--------------|
| Сложност | Ниска | Средна | Висока |
| Deployment | Един артифакт | Един артифакт | Много артифакти |
| База данни | Една | Една | Много |
| Комуникация | Директни извиквания | Контексти + Events | HTTP/gRPC/MQ |
| Латентност | Ниска | Ниска | По-висока |
| Консистентност | ACID | ACID | Eventually consistent |
| DevOps overhead | Нисък | Нисък | Висок |
| Скалиране | Вертикално | Вертикално + горизонтално* | Горизонтално |

*Elixir/BEAM позволява хоризонтално скалиране чрез разпределени ноди

### Защо избрахме модулен монолит?

#### 1. **ACID транзакции между модули**

SAF-T изисква данните да са **консистентни**. Фактура, плащане и счетоводен запис трябва да бъдат създадени атомарно:

```elixir
# Модулен монолит - една транзакция, гарантирана консистентност
Repo.transaction(fn ->
  {:ok, invoice} = Sales.create_invoice(attrs)
  {:ok, payment} = Bank.record_payment(invoice, payment_attrs)
  {:ok, journal} = Accounting.create_journal_entry(invoice, payment)

  invoice
end)
```

При **микросервизи** това изисква Saga pattern или 2PC - значително по-сложно:

```
# Микросервизи - eventual consistency, компенсиращи транзакции
Invoice Service → publish InvoiceCreated
Payment Service → consume InvoiceCreated → publish PaymentRecorded
Accounting Service → consume PaymentRecorded → publish JournalCreated
Saga Orchestrator → rollback при грешка...
```

#### 2. **Простота на deployment**

Един Docker контейнер, една база данни, един лог:

```bash
# Deployment
docker build -t cyber-erp .
docker run -p 4000:4000 cyber-erp

# vs Микросервизи
docker-compose up  # 10+ контейнера, мрежа, volumes, service mesh...
```

#### 3. **По-лесен debugging**

Един процес, един stack trace:

```elixir
# Модулен монолит - линеен stack trace
** (Ecto.NoResultsError)
  apps/cyber_core/lib/cyber_core/sales.ex:42
  apps/cyber_core/lib/cyber_core/accounting.ex:128
  apps/cyber_web/lib/cyber_web/live/invoice_live.ex:56
```

#### 4. **Споделена инфраструктура**

- Един PostgreSQL instance
- Един Redis/Cachex за кеширане
- Една Oban опашка за background jobs
- Един PubSub за real-time events

#### 5. **Екип от 1-5 разработчици**

Микросервизите имат смисъл за екипи 50+. За малък екип overhead-ът не си струва:

| Overhead | Модулен монолит | Микросервизи |
|----------|-----------------|--------------|
| Repo-та | 1 | 10+ |
| CI/CD pipelines | 1 | 10+ |
| Monitoring | 1 dashboard | 10+ dashboards |
| Версиониране на API | Няма нужда | Service contracts |
| Shared libraries | Директен import | Package management |

### Как работи модулният подход в Cyber ERP?

#### Phoenix Umbrella структура

```
cyber_erp/
├── apps/
│   ├── cyber_core/          # Бизнес логика (ядро)
│   │   └── lib/cyber_core/
│   │       ├── accounting/  # Контекст: Счетоводство
│   │       ├── sales/       # Контекст: Продажби
│   │       ├── purchase/    # Контекст: Покупки
│   │       ├── inventory/   # Контекст: Складове
│   │       ├── bank/        # Контекст: Банки
│   │       ├── contacts/    # Контекст: CRM
│   │       └── accounts/    # Контекст: Потребители
│   │
│   └── cyber_web/           # Презентационен слой
│       └── lib/cyber_web/
│           ├── live/        # LiveView модули
│           └── controllers/ # API контролери
│
└── config/                  # Споделена конфигурация
```

#### Контексти (Bounded Contexts)

Всеки модул е **самостоятелен контекст** с ясно дефиниран интерфейс:

```elixir
# apps/cyber_core/lib/cyber_core/sales.ex
defmodule CyberCore.Sales do
  @moduledoc """
  Контекст за управление на продажби.

  Публичен API:
  - list_invoices/2
  - get_invoice!/2
  - create_invoice/1
  - update_invoice/2
  - delete_invoice/1
  """

  # Публични функции - единствен начин за достъп отвън
  def create_invoice(attrs) do
    # Вътрешна имплементация скрита
  end
end
```

#### Комуникация между контексти

**Правило:** Контекстите **не достъпват директно** таблиците на други контексти.

```elixir
# ❌ ГРЕШНО - директен достъп до друг контекст
def create_invoice(attrs) do
  contact = Repo.get!(Contact, attrs.contact_id)  # Директен достъп до Contacts таблица
end

# ✅ ПРАВИЛНО - през публичния API на контекста
def create_invoice(attrs) do
  contact = Contacts.get_contact!(tenant_id, attrs.contact_id)  # През Contacts контекст
end
```

#### Event-driven комуникация (опционално)

За loose coupling между модули използваме Phoenix PubSub:

```elixir
# В Sales контекста
def create_invoice(attrs) do
  with {:ok, invoice} <- do_create_invoice(attrs) do
    # Публикуваме събитие - не ни интересува кой слуша
    Phoenix.PubSub.broadcast(CyberErp.PubSub, "invoices", {:invoice_created, invoice})
    {:ok, invoice}
  end
end

# В Accounting контекста - слуша за събития
def handle_info({:invoice_created, invoice}, state) do
  # Автоматично създаване на счетоводен запис
  create_journal_entry_for_invoice(invoice)
  {:noreply, state}
end
```

### Кога да преминем към микросервизи?

Модулният монолит е проектиран да бъде **лесен за разделяне** когато дойде време:

1. **Ясни граници** - контекстите вече са изолирани
2. **Дефинирани интерфейси** - публичните API-та стават HTTP endpoints
3. **Event-based комуникация** - PubSub става message queue

```
Фаза 1 (сега): Модулен монолит
├── Всички контексти в един процес
└── Една PostgreSQL база

Фаза 2 (бъдеще, ако е необходимо): Хибрид
├── Core модули остават заедно
├── Bank Import → отделен сервис (heavy IO)
└── Document Processing → отделен сервис (AI workload)

Фаза 3 (при нужда): Микросервизи
├── Accounting Service
├── Sales Service
├── Inventory Service
└── ... (всеки контекст = отделен сервис)
```

### BEAM предимства

Elixir/BEAM платформата предлага **вградено скалиране** без микросервизи:

```elixir
# Разпределен клъстер
Node.connect(:"cyber_erp@server2")

# Процеси се разпределят автоматично
GenServer.start_link(__MODULE__, [], name: {:global, :invoice_processor})

# Supervision trees - fault tolerance
children = [
  {CyberCore.Workers.InvoiceWorker, []},
  {CyberCore.Workers.SaftExportWorker, []},
]
Supervisor.start_link(children, strategy: :one_for_one)
```

### Заключение

**Модулният монолит** е правилният избор за Cyber ERP защото:

1. ✅ SAF-T изисква ACID транзакции между модули
2. ✅ Малък екип (1-5 разработчици)
3. ✅ Простота на deployment и debugging
4. ✅ BEAM платформата осигурява скалиране
5. ✅ Ясен път към микросервизи ако потрябва

> "If you can't build a modular monolith, what makes you think you can build microservices?" - Simon Brown

## Технологичен стек

### Backend
- **Elixir 1.16+** - Функционален, конкурентен език
- **Phoenix Framework 1.7+** - Web framework
- **Ecto 3.11+** - ORM и query builder
- **PostgreSQL 14+** - Релационна база данни
- **Oban** - Background jobs и планиране на задачи

### Frontend
- **Phoenix LiveView** - Server-rendered UI с real-time updates
- **React 18** - За сложни компоненти (форми, графики)
- **Alpine.js** - Леки JS интеракции
- **TailwindCSS 3** - Utility-first CSS

### Интеграции
- **ChromicPDF** - PDF генериране
- **Guardian** - JWT authentication
- **НАП API** - Електронни фактури
- **VIES** - ДДС проверки

## Структура на проекта

```
cyber_erp/
├── apps/
│   ├── cyber_core/          # Бизнес логика и схеми
│   │   ├── lib/
│   │   │   ├── cyber_core/
│   │   │   │   ├── accounts/           # Потребители, роли, tenants
│   │   │   │   ├── accounting/         # Счетоводство
│   │   │   │   ├── bank/               # Банкови операции
│   │   │   │   ├── contacts/           # CRM контакти
│   │   │   │   ├── inventory/          # Складове и продукти
│   │   │   │   ├── purchase/           # Покупки
│   │   │   │   ├── sales/              # Продажби
│   │   │   │   └── repo.ex             # Ecto Repo
│   │   │   └── cyber_core.ex
│   │   └── test/
│   │
│   └── cyber_web/           # Web слой
│       ├── lib/
│       │   ├── cyber_web/
│       │   │   ├── controllers/        # REST API контролери
│       │   │   ├── live/               # LiveView модули
│       │   │   ├── components/         # UI компоненти
│       │   │   ├── plugs/              # Middleware
│       │   │   └── endpoint.ex
│       │   └── cyber_web.ex
│       ├── assets/
│       │   ├── js/                     # JavaScript
│       │   │   ├── components/         # React компоненти
│       │   │   └── app.js
│       │   └── css/                    # Styles
│       └── test/
│
├── config/                  # Конфигурация
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── test.exs
│
├── deps/                    # Зависимости
├── mix.exs                  # Project definition
└── README.md
```

## Основни модули

### 1. **Accounts** - Потребители и права
- `Tenant` - Организации (multi-tenancy)
- `User` - Потребители
- Роли и права на достъп

### 2. **Accounting** - Счетоводство
- `Account` - Сметкоплан
- `JournalEntry` / `JournalLine` - Дневници и записи
- `Asset` / `AssetDepreciationSchedule` - Активи и амортизация
- `FinancialAccount` - Финансови сметки
- `FinancialTransaction` - Финансови транзакции

### 3. **Inventory** - Складово стопанство
- `Product` - Продукти и артикули
- `Warehouse` - Складове и локации
- `StockMovement` - Складови движения (in/out/transfer)
- `StockLevel` - Текущи наличности по складове

#### Складови документи (UI)
Всички складови документи имат UI подобен на фактурите, но без ДДС (вътрешни документи):

| Документ | URL | Описание | Ефект |
|----------|-----|----------|-------|
| **ПСД** (Приемателен) | `/goods-receipts/new` | Приемане на стоки от доставчик | ↑ Увеличава наличност |
| **РСД** (Разходен) | `/goods-issues/new` | Издаване на стоки (продажба, вътрешна употреба, мостра) | ↓ Намалява наличност |
| **Трансфер** | `/stock-transfers/new` | Прехвърляне между складове | ↔ Преместване |
| **Брак** | `/stock-adjustments/scrap` | Бракуване на дефектни продукти | ↓ Намалява наличност |
| **Липса** | `/stock-adjustments/shortage` | Регистриране на липсващи стоки | ↓ Намалява наличност |
| **Излишък** | `/stock-adjustments/surplus` | Регистриране на свръхнормени количества | ↑ Увеличава наличност |
| **Инвентаризация** | `/inventory-counts/new` | Преброяване и сверка | Генерира Липса/Излишък |

#### Процес на инвентаризация:
1. Избор на склад → Зареждане на всички артикули с текущи наличности
2. Въвеждане на реално преброени количества
3. Автоматично изчисление на разлики (очаквано vs преброено)
4. Генериране на протоколи за Липса или Излишък

### 4. **Sales** - Продажби
- `Invoice` / `InvoiceLine` - Фактури
- `Quotation` / `QuotationLine` - Оферти
- `Sale` - Продажби

### 5. **Purchase** - Покупки
- `PurchaseOrder` / `PurchaseOrderLine` - Поръчки за покупка
- `SupplierInvoice` / `SupplierInvoiceLine` - Фактури от доставчици

### 6. **Bank** - Банкови операции
- `BankAccount` - Банкови сметки
- `BankTransaction` - Банкови транзакции
- `BankStatement` - Банкови извлечения

### 7. **Contacts** - CRM
- `Contact` - Клиенти и доставчици
- Функции: търсене, филтриране, категоризация

### 8. **Document Processing (AI)** - Обработка на документи с AI
- `DocumentUpload` - Управление на качени файлове (PDF, PNG).
- `ExtractedInvoice` - Съхранение на данни, извлечени от AI (Azure Form Recognizer).
- Асинхронна обработка и валидация на документи.
- Интелигентно мапиране на продукти и банкови сметки към контакти.

## Multi-Tenancy

Системата използва **row-level multi-tenancy**:

1. Всяка таблица има `tenant_id` поле
2. Всички заявки се филтрират автоматично по tenant
3. Tenant се определя от:
   - Subdomain (например: `firma1.cybererp.bg`)
   - HTTP header `X-Tenant-ID`
   - JWT токен

### Примерна заявка:

```elixir
# Вместо:
Repo.all(Product)

# Винаги използваме:
Repo.all(from p in Product, where: p.tenant_id == ^tenant_id)
```

## Контексти (Contexts)

Всеки модул е организиран в контекст, който съдържа бизнес логика:

```elixir
# cyber_core/lib/cyber_core/inventory.ex
defmodule CyberCore.Inventory do
  def list_products(tenant_id, opts \\ [])
  def get_product!(tenant_id, id)
  def create_product(attrs)
  def update_product(product, attrs)
  def delete_product(product)
end
```

## API Layer

### REST API
- Базов URL: `/api`
- Authentication: JWT tokens (Bearer)
- Format: JSON

Примери:
```
POST   /api/auth/login
GET    /api/products
POST   /api/invoices
GET    /api/accounting/accounts
```

### LiveView
- Real-time UI без React
- Websocket връзка
- Server-side rendering

## База данни

### Schema Design

#### Пример: Invoices таблица

```sql
CREATE TABLE invoices (
  id BIGSERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id),
  invoice_no VARCHAR(50) NOT NULL,
  invoice_type VARCHAR(20) DEFAULT 'standard',
  status VARCHAR(20) DEFAULT 'draft',
  issue_date DATE NOT NULL,
  due_date DATE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id),
  subtotal NUMERIC(15,2) DEFAULT 0,
  tax_amount NUMERIC(15,2) DEFAULT 0,
  total_amount NUMERIC(15,2) DEFAULT 0,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  CONSTRAINT invoices_tenant_invoice_no_unique
    UNIQUE (tenant_id, invoice_no)
);

CREATE INDEX invoices_tenant_id_index ON invoices(tenant_id);
CREATE INDEX invoices_contact_id_index ON invoices(contact_id);
CREATE INDEX invoices_issue_date_index ON invoices(issue_date);
```

### Миграции

```bash
# Създаване на нова миграция
mix ecto.gen.migration add_warehouses_table

# Прилагане на миграции
mix ecto.migrate

# Rollback
mix ecto.rollback
```

## Background Jobs (Oban)

Използваме Oban за фонови задачи:

```elixir
defmodule CyberCore.Workers.InvoiceEmailWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invoice_id" => invoice_id}}) do
    # Изпрати имейл с фактура
    :ok
  end
end

# Планиране на задача
%{invoice_id: 123}
|> CyberCore.Workers.InvoiceEmailWorker.new()
|> Oban.insert()
```

## Автентикация и упълномощаване

### JWT Tokens

```elixir
# Генериране на токен
{:ok, token, claims} = Guardian.encode_and_sign(user, %{tenant_id: tenant_id})

# Проверка на токен
{:ok, user, claims} = Guardian.resource_from_token(token)
```

### Plugs

```elixir
# cyber_web/lib/cyber_web/plugs/authenticate.ex
defmodule CyberWeb.Plugs.Authenticate do
  def call(conn, _opts) do
    # Извлича user от JWT токен
  end
end

# cyber_web/lib/cyber_web/plugs/fetch_tenant.ex
defmodule CyberWeb.Plugs.FetchTenant do
  def call(conn, _opts) do
    # Определя tenant от subdomain или header
  end
end
```

## Тестване

```bash
# Всички тестове
mix test

# Един файл
mix test test/cyber_core/accounting_test.exs

# С coverage
mix test --cover
```

### Пример за тест:

```elixir
defmodule CyberCore.InventoryTest do
  use CyberCore.DataCase

  alias CyberCore.Inventory

  describe "products" do
    test "list_products/1 returns all products for tenant" do
      product = insert(:product, tenant_id: 1)
      assert [^product] = Inventory.list_products(1)
    end
  end
end
```

## Deployment

### Docker

```dockerfile
FROM elixir:1.16-alpine AS builder

WORKDIR /app
COPY . .

RUN mix deps.get --only prod
RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM alpine:3.18
RUN apk add --no-cache openssl ncurses-libs

COPY --from=builder /app/_build/prod/rel/cyber_erp /app
CMD ["/app/bin/cyber_erp", "start"]
```

### Environment Variables

```bash
DATABASE_URL=postgresql://user:pass@localhost/cyber_erp_prod
SECRET_KEY_BASE=...
PHX_HOST=cybererp.bg
PORT=4000
```

## Мониторинг

### Telemetry + PromEx

```elixir
# lib/cyber_web/telemetry.ex
defmodule CyberWeb.Telemetry do
  # Phoenix endpoint метрики
  # Ecto query метрики
  # VM метрики
end
```

Метрики на: `/metrics`

## Локализация

Всички текстове са на български:
- UI labels
- Error messages
- Email templates
- PDF документи

```elixir
# priv/gettext/bg/LC_MESSAGES/errors.po
msgid "is required"
msgstr "е задължително"
```

## Best Practices

### 1. Именуване
- Модули: `PascalCase` (CyberCore.Sales.Invoice)
- Функции: `snake_case` (list_products)
- Променливи: `snake_case`

### 2. Changesets
Винаги валидираме данните чрез changesets:

```elixir
def changeset(product, attrs) do
  product
  |> cast(attrs, [:name, :sku, :price])
  |> validate_required([:name, :sku])
  |> validate_length(:sku, max: 50)
  |> unique_constraint([:tenant_id, :sku])
end
```

### 3. Транзакции
За сложни операции използваме транзакции:

```elixir
Repo.transaction(fn ->
  with {:ok, invoice} <- create_invoice(attrs),
       {:ok, _lines} <- create_invoice_lines(invoice, lines_attrs),
       {:ok, _movements} <- create_stock_movements(invoice) do
    invoice
  else
    {:error, reason} -> Repo.rollback(reason)
  end
end)
```

### 4. Preloading
Зареждаме асоциации само при нужда:

```elixir
invoice =
  Invoice
  |> Repo.get!(id)
  |> Repo.preload([:contact, :invoice_lines])
```

## Следващи стъпки

1. ✅ **Основни схеми** (Accounting, Inventory, Sales, Purchase, Bank, Contacts)
2. ✅ **Миграции на базата данни** - Основната структура е изградена.
3. ✅ **Контексти с CRUD функции** - Базовите операции за основните модули са имплементирани.
4. ✅ **API контролери** - Изграден е основен REST API за ключовите ресурси.
5. ✅ **LiveView интерфейси** - Изградени са основните потребителски интерфейси за управление на данни.
6. ⏳ **Интеграции** (НАП, VIES, банки) - В процес на разработка и тестване.
7. ⏳ **PDF генериране** - Има работеща основа, но се нуждае от финализиране за всички документи.
8. ⏳ **Email система** - В процес на разработка.
9. ⏳ **Background jobs (Oban)** - Използва се за AI обработка, предстои разширяване за други задачи.
10. ⏳ **Тестово покритие (Test coverage)** - Покрити са ключови функционалности, но е нужно разширяване.
