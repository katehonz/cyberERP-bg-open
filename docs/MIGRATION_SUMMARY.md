# Cyber ERP - Миграция от Crystal към Elixir Phoenix

## Обобщение

Успешно мигрирахме ERP системата от Crystal (Kemal + Avram) към **Elixir Phoenix**. Новата система е изградена като **umbrella application** с модулна архитектура.

## Архитектура

```
cyber_erp/
├── apps/
│   ├── cyber_core/        # Business логика и данни (Ecto)
│   └── cyber_web/         # Phoenix API endpoints
├── config/                # Конфигурация
└── deps/                  # Dependencies
```

## Имплементирани Модули

### ✅ 1. Accounts (Потребители и организации)
- **Tenants** - Multi-tenancy поддръжка
- **Users** - Потребители с bcrypt хеширане на пароли
- Роли: `admin`, `manager`, `user`
- Автентикация с JWT tokens

**Endpoints:**
- `POST /api/auth/register` - Регистрация
- `POST /api/auth/login` - Вход
- `GET /api/auth/me` - Текущ потребител

### ✅ 2. Contacts (CRM)
- Управление на контакти (клиенти/доставчици)
- Филтриране по тип (company/individual)
- Търсене по име, email, компания

**Endpoints:**
- `GET /api/contacts` - Списък
- `POST /api/contacts` - Създаване
- `GET /api/contacts/:id` - Детайли
- `PUT /api/contacts/:id` - Обновяване
- `DELETE /api/contacts/:id` - Изтриване

### ✅ 3. Inventory (Складово стопанство)
- **Products** - Продукти със SKU, категории
- Управление на количества и цени
- Търсене по име, SKU, описание

**Endpoints:**
- `GET /api/products` - Списък
- `POST /api/products` - Създаване
- `GET /api/products/:id` - Детайли
- `PUT /api/products/:id` - Обновяване
- `DELETE /api/products/:id` - Изтриване

### ✅ 4. Sales (Продажби)
- Фактури и продажби
- Клиентски данни
- Статус tracking (pending/completed/cancelled)
- Филтриране по дата, статус, клиент

**Endpoints:**
- `GET /api/sales` - Списък
- `POST /api/sales` - Създаване
- `GET /api/sales/:id` - Детайли
- `PUT /api/sales/:id` - Обновяване
- `DELETE /api/sales/:id` - Изтриване

### ✅ 5. Accounting (Счетоводство)

#### 5.1 Accounts (Сметкоплан)
- Счетоводни сметки с кодове
- Категории и нормален баланс (дебит/кредит)

**Endpoints:**
- `GET /api/accounting/accounts`
- `POST /api/accounting/accounts`
- `GET /api/accounting/accounts/:id`
- `PUT /api/accounting/accounts/:id`
- `DELETE /api/accounting/accounts/:id`

#### 5.2 Journal Entries (Счетоводни записи)
- Счетоводен журнал
- Journal Lines с дебит/кредит
- Статуси: draft, posted
- Автоматично създаване с редове

**Endpoints:**
- `GET /api/accounting/journal-entries`
- `POST /api/accounting/journal-entries` (с линии)
- `GET /api/accounting/journal-entries/:id`
- `PUT /api/accounting/journal-entries/:id`
- `DELETE /api/accounting/journal-entries/:id`

#### 5.3 Assets (Дълготрайни активи)
- Активи с амортизация
- График на амортизация (AssetDepreciationSchedule)
- Методи: straight_line, declining_balance
- Връзки със счетоводни сметки

**Endpoints:**
- `GET /api/accounting/assets`
- `POST /api/accounting/assets`
- `GET /api/accounting/assets/:id` (с график)
- `PUT /api/accounting/assets/:id`
- `DELETE /api/accounting/assets/:id`

#### 5.4 Financial Accounts & Transactions (Каса/Банка)
- FinancialAccount - касови и банкови сметки
- FinancialTransaction - входящи/изходящи плащания
- Връзка със счетоводния журнал

**Endpoints:**
- `GET /api/accounting/financial-accounts`
- `POST /api/accounting/financial-accounts`
- `GET /api/accounting/financial-transactions`
- `POST /api/accounting/financial-transactions`

## Технически Детайли

### Dependencies
- **Phoenix 1.7** - Web framework
- **Ecto 3.10** - Database ORM
- **PostgreSQL** - Database
- **Bcrypt** - Password hashing
- **CORS Plug** - Cross-origin requests
- **Jason** - JSON encoding/decoding

### Middleware & Plugs
- ✅ `FetchTenant` - Multi-tenancy support
- ✅ `Authenticate` - JWT token validation
- ✅ `RequireAuth` - Protected endpoints
- ✅ `CORSPlug` - CORS headers

### Database Schema
Всички таблици имат:
- `id` - Primary key
- `tenant_id` - Multi-tenancy isolation
- `inserted_at` - Created timestamp
- `updated_at` - Updated timestamp

## Стартиране на проекта

### 1. Инсталация на dependencies
```bash
cd cyber_erp
mix deps.get
```

### 2. Създаване на базата данни
```bash
mix ecto.setup
# или отделно:
mix ecto.create
mix ecto.migrate
mix run apps/cyber_core/priv/repo/seeds.exs
```

### 3. Стартиране на сървъра
```bash
mix phx.server
# или в интерактивен режим:
iex -S mix phx.server
```

Сървърът ще стартира на `http://localhost:4000`

## API Документация

### Authentication
Всички endpoints (освен register/login) изискват:
- Header: `Authorization: Bearer <JWT_TOKEN>`
- Header: `X-Tenant-ID: <tenant_slug>` (опционално)

### Request Format
```json
{
  "contact": {
    "name": "Example Corp",
    "email": "info@example.com",
    "is_company": true
  }
}
```

### Response Format
```json
{
  "data": {
    "id": 1,
    "name": "Example Corp",
    "email": "info@example.com",
    "is_company": true,
    "inserted_at": "2025-10-06T14:30:00Z",
    "updated_at": "2025-10-06T14:30:00Z"
  }
}
```

## Следващи Стъпки

### Препоръчителни подобрения:
1. **Тестове** - Добавяне на unit и integration тестове
2. **Документация** - Swagger/OpenAPI spec
3. **Валидация** - По-детайлна бизнес логика валидация
4. **Permissions** - Role-based access control (RBAC)
5. **Audit Log** - Tracking на промени
6. **Reports** - Финансови отчети
7. **File Upload** - Прикачени файлове към документи
8. **Email** - Notifications (вече има Swoosh setup)
9. **Websockets** - Real-time updates с Phoenix Channels
10. **Deployment** - Docker containerization

### Production deployment:
```bash
# Build release
MIX_ENV=prod mix release

# Run release
_build/prod/rel/cyber_erp/bin/cyber_erp start
```

## Разлики спрямо Crystal версията

| Функция | Crystal (OLD) | Elixir (NEW) |
|---------|---------------|--------------|
| Framework | Kemal | Phoenix |
| ORM | Avram | Ecto |
| Patterns | MVC | Context-based |
| Concurrency | Fibers | Processes/GenServers |
| Hot reload | ❌ | ✅ |
| Umbrella | ❌ | ✅ |
| Multi-tenancy | Partial | Full support |
| CORS | ❌ | ✅ |

## Контакти и Support

За въпроси относно проекта, моля свържете се с development team.

---

**Статус:** ✅ Миграцията е завършена успешно!
**Дата:** 11 Октомври 2025
**Версия:** 0.1.0
