# Multi-Tenant система - Cyber ERP

**Дата:** 2025-10-21
**Версия:** 1.0

---

## 📋 Съдържание

1. [Общ преглед](#общ-преглед)
2. [Архитектура](#архитектура)
3. [Схеми и релации](#схеми-и-релации)
4. [Имплементация](#имплементация)
5. [Употреба](#употреба)
6. [API референция](#api-референция)

---

## Общ преглед

Cyber ERP поддържа **multi-tenant архитектура**, която позволява:

- Една база данни да обслужва множество фирми
- Пълна изолация на данните между фирмите
- Споделени потребители с различни роли във всяка фирма
- Лесно превключване между фирми през UI

### Ключови концепции

1. **Tenant** (Фирма) - Отделна юридическа единица с изолирани данни
2. **User** (Потребител) - Може да има достъп до множество фирми
3. **Current Tenant** - Активната фирма за текущата сесия

---

## Архитектура

### Модел на данните

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│   Tenants   │◄──────┤ UserTenants  ├──────►│    Users    │
│             │       │              │       │             │
│ - id        │       │ - user_id    │       │ - id        │
│ - name      │       │ - tenant_id  │       │ - email     │
│ - slug      │       │ - role       │       │ - name      │
│ - currency  │       │ - is_active  │       │             │
└─────────────┘       └──────────────┘       └─────────────┘
      │
      │ tenant_id (FK)
      │
      ▼
┌─────────────────────┐
│  Business Tables    │
│                     │
│ - products          │
│ - invoices          │
│ - contacts          │
│ - accounts          │
│ - ...               │
└─────────────────────┘
```

### Изолация на данни

Всяка бизнес таблица съдържа `tenant_id` поле:

```sql
CREATE TABLE invoices (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id),
  invoice_no VARCHAR(50),
  ...
);

CREATE INDEX idx_invoices_tenant ON invoices(tenant_id);
```

---

## Схеми и релации

### 1. Tenant Schema

**Файл:** `lib/cyber_core/accounts/tenant.ex`

```elixir
defmodule CyberCore.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :base_currency_code, :string, default: "BGN"
    field :base_currency_changed_at, :utc_datetime
    field :in_eurozone, :boolean, default: false
    field :eurozone_entry_date, :date

    timestamps()
  end
end
```

**Полета:**
- `name` - Име на фирмата
- `slug` - URL-friendly идентификатор
- `base_currency_code` - Основна валута (BGN, EUR, USD, GBP)
- `in_eurozone` - Дали фирмата е в еврозоната
- `eurozone_entry_date` - Дата на влизане в еврозоната

### 2. User Schema

**Файл:** `lib/cyber_core/accounts/user.ex`

```elixir
defmodule CyberCore.Accounts.User do
  use Ecto.Schema

  schema "users" do
    belongs_to :tenant, Tenant  # Legacy поле
    many_to_many :tenants, Tenant, join_through: "user_tenants"

    field :email, :string
    field :hashed_password, :string
    field :first_name, :string
    field :last_name, :string
    field :role, :string, default: "user"

    timestamps()
  end
end
```

**Забележка:** `belongs_to :tenant` е запазено за backwards compatibility.

### 3. UserTenant Schema (Join Table)

**Файл:** `lib/cyber_core/accounts/user_tenant.ex`

```elixir
defmodule CyberCore.Accounts.UserTenant do
  use Ecto.Schema

  @roles ~w(admin manager user)

  schema "user_tenants" do
    belongs_to :user, User
    belongs_to :tenant, Tenant

    field :role, :string, default: "user"
    field :is_active, :boolean, default: true

    timestamps()
  end
end
```

**Роли:**
- `admin` - Пълен достъп до фирмата
- `manager` - Ограничен административен достъп
- `user` - Основен достъп

---

## Имплементация

### 1. Миграции

**Създаване на user_tenants таблица:**

```bash
mix ecto.gen.migration create_user_tenants
```

```elixir
defmodule CyberCore.Repo.Migrations.CreateUserTenants do
  use Ecto.Migration

  def change do
    create table(:user_tenants) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :role, :string, default: "user", null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:user_tenants, [:user_id, :tenant_id])
    create index(:user_tenants, [:tenant_id])
  end
end
```

### 2. LiveView Hook

**Файл:** `lib/cyber_web/live/hooks/tenant_hook.ex`

Hook-ът автоматично зарежда информация за фирмите във всяко LiveView:

```elixir
defmodule CyberWeb.Live.Hooks.TenantHook do
  import Phoenix.LiveView
  alias CyberCore.Accounts

  def on_mount(:default, _params, session, socket) do
    current_tenant_id = session["current_tenant_id"] || 1
    tenants = Accounts.list_tenants()
    current_tenant = Accounts.get_tenant!(current_tenant_id)

    {:cont,
     socket
     |> assign(:current_tenant_id, current_tenant_id)
     |> assign(:current_tenant, current_tenant)
     |> assign(:tenants, tenants)
     |> attach_hook(:handle_tenant_switch_event, :handle_event, &handle_tenant_switch_event/3)}
  end

  # Обработка на събитието за превключване
  defp handle_tenant_switch_event("switch_tenant", %{"tenant_id" => id}, socket) do
    tenant_id = String.to_integer(id)
    tenant = Accounts.get_tenant!(tenant_id)

    {:halt,
     socket
     |> assign(:current_tenant_id, tenant_id)
     |> assign(:current_tenant, tenant)
     |> put_flash(:info, "Превключихте към #{tenant.name}")}
  end
end
```

**Интегриране във всички LiveView:**

```elixir
# lib/cyber_web.ex
def live_view do
  quote do
    use Phoenix.LiveView,
      layout: {CyberWeb.Layouts, :app}

    on_mount CyberWeb.Live.Hooks.TenantHook

    unquote(html_helpers())
  end
end
```

### 3. UI Селектор

**Файл:** `lib/cyber_web/components/layouts/app.html.heex`

```heex
<div class="border-b border-zinc-200 px-4 py-3">
  <label class="block text-xs font-semibold uppercase tracking-wide text-zinc-400 mb-2">
    Активна фирма
  </label>
  <form phx-change="switch_tenant">
    <select
      id="tenant-selector"
      name="tenant_id"
      class="w-full rounded-lg border-zinc-300 text-sm"
    >
      <%= for tenant <- @tenants do %>
        <option value={tenant.id} selected={tenant.id == @current_tenant_id}>
          <%= tenant.name %>
        </option>
      <% end %>
    </select>
  </form>
</div>
```

---

## Употреба

### Управление на фирми

#### Списък с фирми

URL: http://localhost:4000/tenants

Показва таблица с всички фирми:
- Име
- Slug
- Основна валута
- Еврозона статус
- Действия (Редактиране, Изтриване)

#### Добавяне на нова фирма

1. Кликнете "+ Нова фирма"
2. Попълнете:
   - Име на фирмата
   - Slug (за URL, напр. "moya-firma")
   - Основна валута (BGN/EUR/USD/GBP)
   - Във еврозоната (Да/Не)
   - Дата на влизане в еврозоната (опционално)
3. Кликнете "Запази"

#### Редактиране на фирма

1. От списъка кликнете "Редактирай"
2. Променете желаните полета
3. Кликнете "Запази"

### Управление на достъп

#### Даване на достъп до фирма

```elixir
# В IEx или миграция
alias CyberCore.Accounts

# Даване на достъп
{:ok, _user_tenant} = Accounts.grant_tenant_access(
  user_id: 1,
  tenant_id: 2,
  role: "manager"
)
```

#### Проверка на достъп

```elixir
has_access = Accounts.user_has_tenant_access?(user_id, tenant_id)
# => true или false
```

#### Списък с фирми на потребител

```elixir
user_tenants = Accounts.list_user_tenants(user_id)
# => [
#   %{tenant: %Tenant{}, role: "admin", user_tenant_id: 1},
#   %{tenant: %Tenant{}, role: "user", user_tenant_id: 2}
# ]
```

### Превключване между фирми

**От UI:**
1. Отворете dropdown "Активна фирма" в sidebar-а
2. Изберете желаната фирма
3. Системата автоматично презарежда данните за новата фирма

**Програмно:**
```elixir
# В LiveView
send(self(), {:tenant_switched, new_tenant_id})
```

### Филтриране на данни по tenant

**В контекст модули:**

```elixir
defmodule CyberCore.Sales do
  def list_invoices(tenant_id) do
    from(i in Invoice,
      where: i.tenant_id == ^tenant_id,
      order_by: [desc: i.issue_date]
    )
    |> Repo.all()
  end

  def get_invoice!(tenant_id, id) do
    Repo.get_by!(Invoice, tenant_id: tenant_id, id: id)
  end
end
```

**В LiveView:**

```elixir
def mount(_params, _session, socket) do
  tenant_id = socket.assigns.current_tenant_id
  invoices = Sales.list_invoices(tenant_id)

  {:ok, assign(socket, :invoices, invoices)}
end
```

---

## API референция

### Accounts контекст

**Файл:** `lib/cyber_core/accounts.ex`

#### Функции за Tenants

```elixir
# Списък с всички фирми
@spec list_tenants() :: [Tenant.t()]
def list_tenants()

# Вземане на фирма по ID
@spec get_tenant!(integer()) :: Tenant.t()
def get_tenant!(id)

# Вземане на фирма по slug
@spec get_tenant_by_slug(String.t()) :: Tenant.t() | nil
def get_tenant_by_slug(slug)

# Създаване на фирма
@spec create_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
def create_tenant(attrs)

# Обновяване на фирма
@spec update_tenant(Tenant.t(), map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
def update_tenant(tenant, attrs)

# Изтриване на фирма
@spec delete_tenant(Tenant.t()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
def delete_tenant(tenant)
```

#### Функции за User-Tenant релации

```elixir
# Списък с фирми на потребител
@spec list_user_tenants(integer()) :: [map()]
def list_user_tenants(user_id)

# Проверка за достъп
@spec user_has_tenant_access?(integer(), integer()) :: boolean()
def user_has_tenant_access?(user_id, tenant_id)

# Даване на достъп
@spec grant_tenant_access(integer(), integer(), String.t()) ::
  {:ok, UserTenant.t()} | {:error, Ecto.Changeset.t()}
def grant_tenant_access(user_id, tenant_id, role \\ "user")

# Премахване на достъп
@spec revoke_tenant_access(integer(), integer()) ::
  {:ok, UserTenant.t()} | {:error, :not_found}
def revoke_tenant_access(user_id, tenant_id)

# Обновяване на роля
@spec update_user_tenant_role(integer(), integer(), String.t()) ::
  {:ok, UserTenant.t()} | {:error, :not_found | Ecto.Changeset.t()}
def update_user_tenant_role(user_id, tenant_id, role)
```

#### Функции за валута

```elixir
# Промяна на основната валута
@spec change_base_currency(Tenant.t(), map()) ::
  {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
def change_base_currency(tenant, attrs)

# Влизане в еврозоната
@spec enter_eurozone(Tenant.t(), Date.t()) ::
  {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
def enter_eurozone(tenant, entry_date \\ Date.utc_today())

# Вземане на основната валута
@spec get_base_currency(Tenant.t()) :: String.t()
def get_base_currency(tenant)
```

### Settings контекст

**Файл:** `lib/cyber_core/settings.ex`

```elixir
# Вземане на основната валута за фирма
@spec get_default_currency(integer()) :: String.t()
def get_default_currency(tenant_id)

# Пример
default_currency = Settings.get_default_currency(1)
# => "BGN"
```

---

## Примери

### Пример 1: Създаване на нова фирма

```elixir
alias CyberCore.Accounts

{:ok, tenant} = Accounts.create_tenant(%{
  name: "Моята ЕООД",
  slug: "moyata-eood",
  base_currency_code: "BGN"
})

IO.inspect(tenant)
# => %Tenant{
#   id: 2,
#   name: "Моята ЕООД",
#   slug: "moyata-eood",
#   base_currency_code: "BGN",
#   in_eurozone: false
# }
```

### Пример 2: Даване на достъп до фирма

```elixir
# User с ID 1 получава достъп до Tenant с ID 2 като manager
{:ok, user_tenant} = Accounts.grant_tenant_access(1, 2, "manager")

# Проверка на достъп
Accounts.user_has_tenant_access?(1, 2)
# => true

# Списък с фирми на потребителя
user_tenants = Accounts.list_user_tenants(1)
# => [
#   %{tenant: %Tenant{id: 1, name: "Главна фирма"}, role: "admin"},
#   %{tenant: %Tenant{id: 2, name: "Моята ЕООД"}, role: "manager"}
# ]
```

### Пример 3: Филтриране на данни

```elixir
# В контекст
defmodule CyberCore.Inventory do
  def list_products(tenant_id) do
    from(p in Product, where: p.tenant_id == ^tenant_id)
    |> Repo.all()
  end
end

# В LiveView
def mount(_params, _session, socket) do
  products = Inventory.list_products(socket.assigns.current_tenant_id)
  {:ok, assign(socket, :products, products)}
end
```

### Пример 4: Промяна на валута

```elixir
tenant = Accounts.get_tenant!(1)

# Проверка дали може да се променя
can_change = not tenant.in_eurozone and
  (is_nil(tenant.eurozone_entry_date) or
   Date.compare(Date.utc_today(), tenant.eurozone_entry_date) == :lt)

if can_change do
  {:ok, updated_tenant} = Accounts.change_base_currency(tenant, %{
    base_currency_code: "EUR"
  })
end
```

---

## Сигурност

### 1. Изолация на данни

- **Всички** бизнес queries използват `tenant_id` филтър
- Unique constraints включват `tenant_id`
- Indexes включват `tenant_id` за производителност

```sql
-- Пример за индекс
CREATE INDEX idx_products_tenant ON products(tenant_id, sku);

-- Пример за unique constraint
CREATE UNIQUE INDEX idx_products_tenant_sku
  ON products(tenant_id, sku);
```

### 2. Access Control

- Проверка на `user_has_tenant_access?` преди достъп
- Роли (`admin`, `manager`, `user`) за fine-grained permissions
- `is_active` флаг за временно деактивиране на достъп

### 3. Валидация

- Slug валидация: само малки букви, цифри и тирета
- Unique slug между фирмите
- Валутна валидация (само BGN, EUR, USD, GBP)
- Еврозона правила (автоматично EUR при влизане)

---

## Миграция

### От single-tenant към multi-tenant

Ако мигрирате съществуваща single-tenant система:

1. **Добавете tenant_id към всички таблици:**

```elixir
def change do
  alter table(:invoices) do
    add :tenant_id, :integer
  end

  # Попълнете с default tenant
  execute "UPDATE invoices SET tenant_id = 1"

  alter table(:invoices) do
    modify :tenant_id, :integer, null: false
  end

  create index(:invoices, [:tenant_id])
end
```

2. **Създайте default tenant:**

```elixir
{:ok, _tenant} = Accounts.create_tenant(%{
  name: "Главна фирма",
  slug: "main",
  base_currency_code: "BGN"
})
```

3. **Обновете всички queries да включват tenant_id**

---

## Производителност

### Оптимизации

1. **Composite indexes:**
```sql
CREATE INDEX idx_invoices_tenant_date
  ON invoices(tenant_id, issue_date DESC);
```

2. **Partitioning (за много големи системи):**
```sql
CREATE TABLE invoices (
  ...
) PARTITION BY LIST (tenant_id);
```

3. **Caching:**
```elixir
# Cache tenant data
defmodule TenantCache do
  use Nebulex.Cache,
    otp_app: :cyber_core,
    adapter: Nebulex.Adapters.Local
end
```

---

## Troubleshooting

### Проблем: "Tenant not found"

```elixir
# Проверете дали tenant съществува
Repo.get(Tenant, tenant_id)

# Проверете session
current_tenant_id = get_session(conn, "current_tenant_id")
```

### Проблем: "Access denied"

```elixir
# Проверете user_tenants
Repo.get_by(UserTenant, user_id: user_id, tenant_id: tenant_id)

# Проверете is_active флага
```

### Проблем: "Data leakage between tenants"

```elixir
# Винаги използвайте tenant_id във WHERE
from(i in Invoice, where: i.tenant_id == ^tenant_id)

# НЕ използвайте:
from(i in Invoice, where: i.id == ^id)  # ГРЕШКА!
```

---

## Заключение

Multi-tenant архитектурата на Cyber ERP осигурява:

- ✅ Пълна изолация на данни
- ✅ Споделени потребители
- ✅ Лесно управление
- ✅ Гъвкави роли
- ✅ Производителност

За допълнителни въпроси вижте [IMPLEMENTATION-STATUS.md](./IMPLEMENTATION-STATUS.md)

---

**Последна актуализация:** 2025-10-21
**Автор:** Claude (AI асистент) + dvg
