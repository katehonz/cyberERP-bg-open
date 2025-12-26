# Authentication & Authorization System

Пълна система за вход, права и управление на потребители в Cyber ERP.

## 📋 Съдържание

- [Преглед](#преглед)
- [Функционалности](#функционалности)
- [Архитектура](#архитектура)
- [Използване](#използване)
- [Демо потребители](#демо-потребители)
- [Конфигурация](#конфигурация)

---

## Преглед

Системата предоставя:
- ✅ **Login/Logout** - Пълна authentication система
- ✅ **Session Management** - Cookie-based сесии
- ✅ **Role-based Permissions** - Права по роли
- ✅ **Multi-tenant Support** - Поддръжка на множество фирми
- ✅ **Permissions UI** - Графичен интерфейс за управление на права

---

## Функционалности

### 1. Authentication (Удостоверяване)

#### Login
- Форма за вход с email, парола и избор на фирма
- Валидация на credentials с bcrypt
- Автоматично създаване на сесия
- Redirect към dashboard след успешен вход

#### Logout
- Бутон "Изход" в sidebar-а
- Изчистване на сесията
- Redirect към login страница

#### Session Management
- Cookie-based сесии
- Автоматично refresh на session timeout
- Защита срещу CSRF атаки

### 2. Authorization (Упълномощаване)

#### Role-based Access Control (RBAC)
Системата поддържа следните роли:

| Роля | Описание | Права |
|------|----------|-------|
| **superadmin** | Супер администратор | Всички права + управление на permissions |
| **admin** | Администратор | Всички CRUD операции |
| **manager** | Мениджър | CRUD без delete |
| **user** | Потребител | Основни операции (create, read, update) |
| **observer** | Наблюдател | Само четене (read) |

#### Permissions (Права)
Детайлни права за различни модули:

**Contacts:**
- `contacts.create` - Създаване на контакти
- `contacts.read` - Четене на контакти
- `contacts.update` - Редакция на контакти
- `contacts.delete` - Изтриване на контакти

**Products:**
- `products.create` - Създаване на продукти
- `products.read` - Четене на продукти
- `products.update` - Редакция на продукти
- `products.delete` - Изтриване на продукти

**Invoices:**
- `invoices.create` - Издаване на фактури
- `invoices.read` - Преглед на фактури
- `invoices.update` - Редакция на фактури
- `invoices.delete` - Изтриване на фактури

### 3. Permissions Management UI

Достъпен само за **superadmin** на `/permissions`.

**Функции:**
- Матрица роли x права
- Визуално assign/revoke на права
- Запазване в реално време
- Валидация и error handling

---

## Архитектура

### Backend Components

#### 1. Schemas

**User** (`apps/cyber_core/lib/cyber_core/accounts/user.ex`)
```elixir
schema "users" do
  belongs_to :tenant, Tenant
  many_to_many :tenants, Tenant, join_through: "user_tenants"

  field :email, :string
  field :hashed_password, :string
  field :first_name, :string
  field :last_name, :string
  field :role, :string  # superadmin, admin, manager, user, observer

  timestamps()
end
```

**Permission** (`apps/cyber_core/lib/cyber_core/guardian/permission.ex`)
```elixir
schema "permissions" do
  field :name, :string        # e.g. "invoices.create"
  field :description, :string

  timestamps()
end
```

**RolePermission** (`apps/cyber_core/lib/cyber_core/guardian/role_permission.ex`)
```elixir
schema "role_permissions" do
  field :role, :string        # e.g. "admin"
  belongs_to :permission, Permission

  timestamps()
end
```

#### 2. Contexts

**Accounts** (`apps/cyber_core/lib/cyber_core/accounts.ex`)
- `authenticate_user/3` - Валидация на credentials
- `register_user/1` - Регистрация на нов потребител
- `get_user/2` - Зареждане на потребител
- `list_users/1` - Списък с потребители

**Guardian** (`apps/cyber_core/lib/cyber_core/guardian.ex`)
- `list_permissions/0` - Всички права
- `grant/2` - Даване на право на роля
- `revoke/2` - Премахване на право от роля
- `get_role_permissions/1` - Права за конкретна роля
- `can?/3` - Проверка дали потребител има право

### Frontend Components

#### 1. LiveView Modules

**LoginLive** (`apps/cyber_web/lib/cyber_web/live/login_live.ex`)
- Форма за вход
- Валидация
- Session creation
- Без AuthHook (за да избегне redirect loop)

**PermissionLive** (`apps/cyber_web/lib/cyber_web/live/permission_live/index.ex`)
- Матрица за управление на права
- CRUD операции за permissions
- Само за superadmin

#### 2. Hooks

**AuthHook** (`apps/cyber_web/lib/cyber_web/live/hooks/auth_hook.ex`)
- Зареждане на `current_user` от сесията
- Auto-redirect към `/login` ако няма сесия
- Режим `:allow_not_authenticated` за публични страници

**TenantHook** (`apps/cyber_web/lib/cyber_web/live/hooks/tenant_hook.ex`)
- Зареждане на `current_tenant`
- Списък с всички tenants
- Tenant switching

#### 3. Controllers

**SessionController** (`apps/cyber_web/lib/cyber_web/controllers/session_controller.ex`)
- `create/2` - Login endpoint (POST /login)
- `delete/2` - Logout endpoint (DELETE /logout)

---

## Използване

### 1. Стартиране на системата

```bash
# Стартиране на сървъра
./start.sh

# Спиране на сървъра
./stop.sh
```

### 2. Login

1. Отворете `http://localhost:4000`
2. Автоматично ще бъдете редиректнати към `/login`
3. Изберете фирма от dropdown
4. Въведете email и парола
5. Натиснете "Вход"

### 3. Logout

1. Кликнете на бутона "Изход" в долната част на sidebar-а
2. Автоматично ще бъдете излогнати и редиректнати към `/login`

### 4. Управление на права (само superadmin)

1. Влезте като superadmin
2. Отидете на `/permissions`
3. Използвайте матрицата за assign/revoke на права
4. Натиснете "Запази промените"

---

## Демо потребители

Системата идва с предварително създадени демо потребители:

| Роля | Email | Парола | Описание |
|------|-------|--------|----------|
| **Superadmin** | `superadmin@example.com` | `password123` | Пълен достъп + управление на права |
| **Admin** | `admin@demo.com` | `password123` | Всички CRUD операции |
| **User** | `user@demo.com` | `password123` | Основни операции без delete |
| **Observer** | `observer@demo.com` | `password123` | Само четене |

**Фирма:** Демо ЕООД (ID: 1)

---

## Конфигурация

### Session Timeout

По подразбиране сесиите са настроени в `config/config.exs`:

```elixir
config :cyber_web, CyberWeb.Endpoint,
  live_view: [signing_salt: "..."],
  # Session timeout - 24 часа
  session_options: [
    store: :cookie,
    key: "_cyber_web_key",
    signing_salt: "...",
    max_age: 86400  # 24 hours
  ]
```

### Password Hashing

Паролите се хешират с **bcrypt** (по подразбиране 12 rounds).

Конфигурация в User schema:
```elixir
defp put_password_hash(
  %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
) do
  change(changeset, %{hashed_password: Bcrypt.hash_pwd_salt(password)})
end
```

### CSRF Protection

Автоматична защита срещу CSRF атаки в router:
```elixir
pipeline :browser do
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end
```

---

## Разширяване на системата

### Добавяне на ново право

1. Добавете правото в seeds:
```elixir
# apps/cyber_core/priv/repo/seeds.exs
permissions = [
  %{name: "new_module.create", description: "Create new module"},
  %{name: "new_module.read", description: "Read new module"},
  # ...
]
```

2. Изпълнете seeds:
```bash
mix run apps/cyber_core/priv/repo/seeds.exs
```

3. Assign-нете права на роли през UI (`/permissions`)

### Добавяне на нова роля

1. Добавете ролята в User schema:
```elixir
# apps/cyber_core/lib/cyber_core/accounts/user.ex
@roles ~w(superadmin admin manager user observer new_role)
```

2. Добавете я в PermissionLive:
```elixir
# apps/cyber_web/lib/cyber_web/live/permission_live/index.ex
@roles ~w(admin user observer new_role)
```

3. Добавете форматиране:
```elixir
defp format_role("new_role"), do: "Нова роля"
```

### Проверка на права в код

```elixir
# В LiveView
def mount(_params, _session, socket) do
  user = socket.assigns.current_user
  tenant_id = socket.assigns.current_tenant_id

  if Guardian.can?(user, tenant_id, "invoices.create") do
    # Потребителят има право
  else
    # Потребителят няма право
  end
end
```

---

## Сигурност

### Best Practices

✅ **Паролите никога не се съхраняват в plain text**
✅ **Използва се bcrypt за hashing**
✅ **CSRF защита на всички форми**
✅ **Session cookies са httpOnly и secure**
✅ **Auto-logout при invalid session**
✅ **Rate limiting на login опити** (препоръчително в production)

### Production препоръки

1. **HTTPS само** - Изключете HTTP в production
2. **Strong session secrets** - Генерирайте силни signing salts
3. **Session timeout** - Намалете max_age за по-висока сигурност
4. **2FA** - Добавете two-factor authentication
5. **Password policies** - Минимална дължина, complexity requirements
6. **Audit logging** - Логвайте login/logout събития
7. **Rate limiting** - Ограничете login опитите

---

## Troubleshooting

### "Permission denied" при стартиране

Изпълнете:
```bash
sudo chown -R dvg:dvg .
./start.sh
```

### "Too many redirects" на login страница

Изтрийте cookies и опитайте отново, или проверете че LoginLive не използва AuthHook.

### Dashboard не се зарежда

Dashboard-ът има error handling за липсващи таблици. Проверете логовете за повече информация.

---

## Лиценз

MIT License - Вижте LICENSE файла за детайли.
