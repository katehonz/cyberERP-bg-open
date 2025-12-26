# 🏢 Cyber ERP

> **Система за управление на бизнес ресурси (ERP) на български език**

[![Elixir Version](https://img.shields.io/badge/Elixir-1.16%2B-purple.svg)](https://elixir-lang.org)
[![Phoenix Framework](https://img.shields.io/badge/Phoenix-1.7%2B-orange.svg)](https://www.phoenixframework.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-blue.svg)](https://www.postgresql.org)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

---

## 📋 Съдържание

- [За проекта](#за-проекта)
- [Технологии](#технологии)
- [Архитектура](#архитектура)
- [Модули](#модули)
- [Бърз старт](#бърз-старт)
- [Документация](#документация)
- [Разработка](#разработка)

---

## 🎯 За проекта

**Cyber ERP** е модерна, мащабируема ERP система изградена с **Elixir** и **Phoenix Framework**, специално разработена за българския пазар. Системата предоставя пълен набор от функционалности за управление на бизнес процеси:

- 💼 **Счетоводство** - Сметкоплан, дневници, финансови отчети
- 📦 **Складово стопанство** - Продукти, складове, наличности
- 🛒 **Продажби** - Фактури, оферти, POS
- 🛍️ **Покупки** - Поръчки, фактури от доставчици
- 🏦 **Банки** - Банкови сметки, транзакции, извлечения
- 🤖 **AI обработка** - Автоматично извличане на данни от PDF фактури
- 📊 **ДДС и SAF-T** - ДДС декларации, NAP файлове, данъчни справки

### 🌍 Език на проекта

**Важно:** Този проект е на **български език**. Всички потребителски интерфейси, документация, коментари в кода и комуникация се водят на български.

---

## 🛠️ Технологии

### Backend

| Технология | Използване | Версия |
|------------|------------|--------|
| **Elixir** | Функционален език за надеждни приложения | 1.16+ |
| **Phoenix Framework** | Web framework с real-time | 1.7+ |
| **Phoenix LiveView** | Server-side rendering с real-time updates | Latest |
| **Ecto** | Database wrapper и query builder | 3.10+ |
| **PostgreSQL** | Релационна база данни | 14+ |

### Frontend

| Технология | Използване |
|------------|------------|
| **Phoenix LiveView** | Основен UI (списъци, таблици, навигация) |
| **React** | Сложни форми, rich text editors, графики |
| **Alpine.js** | Леки клиентски интерактивности |
| **Tailwind CSS** | Utility-first CSS framework |
| **Recharts** | Графики и визуализации на данни |

### Интеграции

| Услуга | Използване |
|--------|------------|
| **Azure Form Recognizer** | AI обработка на PDF фактури |
| **S3 Hetzner** | Cloud съхранение на документи |
| **НАП API** | ДДС декларации (планирано) |
| **VIES** | Проверка на ДДС номера (планирано) |

---

## 🏗️ Архитектура

### Модулен монолит (Modular Monolith)

Cyber ERP използва архитектурата **Modular Monolith** - средно решение между класическия монолит и микросервизите:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Cyber ERP (Umbrella App)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │Accounting│  │  Sales   │  │Inventory │  │   Bank   │        │
│  │  Context │  │  Context │  │  Context │  │  Context │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │              │              │              │              │
│       └──────────────┴──────────────┴──────────────┘              │
│                           │                                       │
│                 ┌─────────┴─────────┐                             │
│                 │   Shared Kernel    │                             │
│                 │  (Repo, PubSub)    │                             │
│                 └────────────────────┘                             │
├─────────────────────────────────────────────────────────────────┤
│                       PostgreSQL Database                          │
└─────────────────────────────────────────────────────────────────┘
```

### Защо модулен монолит?

| Предимство | Описание |
|------------|----------|
| ✅ **ACID транзакции** | Гарантирана консистентност между модули |
| ✅ **Лесен deployment** | Един Docker контейнер |
| ✅ **BEAM скалиране** | Вградена възможност за хоризонтално скалиране |
| ✅ **По-лесен debugging** | Една codebase, един server |
| ✅ **Ясен път напред** | Може да се раздели на микросервизи при нужда |

Повече информация: [Архитектура](docs/ARCHITECTURE_BG.md)

### Хибриден подход: LiveView + React

**LiveView компоненти** (server-side):
- Списъци и таблици с данни
- Dashboard и отчети
- Навигация и layouts
- Real-time notifications

**React компоненти** (client-side):
- Сложни форми с много валидации
- Rich text editors
- Интерактивни графики (Recharts)
- Drag & drop интерфейси

---

## 📦 Модули

### ✅ Завършени модули

| Модул | Функционалности | Статус |
|-------|-----------------|--------|
| **Accounts** | Потребители, организации, multi-tenancy, RBAC | ✅ 100% |
| **Authentication** | Login/Logout, session management, permissions | ✅ 100% |
| **Счетоводство** | Сметкоплан, дневници, записи, активи | ✅ 90% |
| **Складово стопанство** | Продукти, складове, движения, наличности | ✅ 100% |
| **Продажби** | Фактури, оферти, продажби | ✅ 100% |
| **Покупки** | Поръчки за покупка, фактури от доставчици | ✅ 100% |
| **Банки** | Банкови сметки, транзакции, извлечения | ✅ 90% |
| **ДДС (VAT)** | ДДС дневници, декларации, NAP файлове | ✅ 100% |
| **AI обработка** | Azure Form Recognizer, S3 storage | ✅ 100% |
| **Contacts (CRM)** | Клиенти и доставчици | ✅ 100% |

### 🚧 В разработка

| Модул | Прогрес | Детайли |
|-------|---------|---------|
| **SAF-T** | 70% | Header ✅, MasterFiles ✅, GeneralLedger ⏳, SourceDocuments ⏳ |
| **LiveView UI** | 50% | Базови интерфейси, нужда се разширяване |
| **Тестове** | 30% | Unit и integration тестове |

### 📋 Планирани

- HR (Човешки ресурси)
- POS (Каса)
- Production (Производство)
- Planning (Планиране)
- Reporting (Отчети)

---

## 🚀 Бърз старт

### Изисквания

- **Elixir** 1.16+
- **Erlang/OTP** 26+
- **PostgreSQL** 14+
- **Node.js** 18+ (за frontend assets)

### Инсталация

```bash
# 1. Клонирай проекта
cd /home/dvg/z-nim-proloq/cyberERP-open-bg

# 2. Инсталирай зависимостите
mix deps.get

# 3. Създай база данни и мигрирай
mix ecto.setup

# 4. Стартирай сървъра
./start.sh
# или директно:
mix phx.server
```

Приложението ще бъде достъпно на `http://localhost:4000`

### 🔐 Demo потребители

| Роля | Email | Парола | Права |
|------|-------|--------|-------|
| **Superadmin** | `superadmin@example.com` | `password123` | Всички + управление на права |
| **Admin** | `admin@demo.com` | `password123` | Всички операции |
| **User** | `user@demo.com` | `password123` | Основни операции |
| **Observer** | `observer@demo.com` | `password123` | Само четене |

---

## 📚 Документация

За подробна информация вижте [docs/](docs/) директорията:

### 📖 Основна документация

| Документ | Описание |
|----------|----------|
| [📘 Документация (index)](docs/README.md) **← Започнете оттук!** | Пълен индекс на цялата документация |
| [🚀 Бърз старт](docs/QUICK_START_BG.md) | Инструкции за разработчици |
| [🏗️ Архитектура](docs/ARCHITECTURE_BG.md) | Архитектурни принципи и решения |
| [📊 Статус на проекта](docs/PROJECT_STATUS_BG.md) | Текущ прогрес и метрики |
| [📝 Резюме](docs/SUMMARY_BG.md) | Кратко обобщение на проекта |

### 🏢 Бизнес модули

| Модул | Документация |
|-------|--------------|
| Счетоводство | [Счетоводен модул](docs/ACCOUNTING_REFACTORING.md) |
| ДДС | [ДДС система](docs/VAT-docs.md), [Видове документи](docs/VAT_DOCUMENT_TYPES.md) |
| Начални салда | [Начални салда](docs/OPENING_BALANCES.md) |
| Дълготрайни активи | [ДМА модул](docs/FIXED_ASSETS_MODULE.md), [API](docs/API_FIXED_ASSETS.md) |
| Склад | [Инвентар модул](apps/cyber_core/lib/cyber_core/inventory/README.md) |
| Ценови листи | [Цени и отстъпки](docs/PRICE_LISTS.md) |
| Банки | [Банкови профили](docs/BANK_PROFILES.md) |
| SAFT-T | [SAF-T docs](docs/SAFT-docs.md), [Mapping](docs/SAFT_MAPPING.md) |

### 🔧 Техническа документация

| Тема | Документация |
|------|--------------|
| Multi-tenancy | [Multi-Tenant](docs/MULTI-TENANT.md) |
| Роли и права | [User Roles & Permissions](docs/USER_ROLES_AND_PERMISSIONS.md) |
| Кеширане | [Cache Quickstart](docs/CACHE_QUICKSTART.md) |
| Frontend | [Frontend интеграция](docs/FRONTEND_INTEGRATION.md) |
| API | [API документация](docs/API_DOCS_BG.md) |
| Миграции | [Migration Summary](docs/MIGRATION_SUMMARY.md) |
| Номенклатури | [Setup Nomenclatures](docs/SETUP_NOMENCLATURES.md) |
| Номерация | [Document Numbering](docs/DOCUMENT_NUMBERING.md) |

### 🔌 Интеграции

| Интеграция | Документация |
|------------|--------------|
| AI обработка | [AI Invoice Processing](docs/AI_INVOICE_PROCESSING.md) |
| Azure Form Recognizer | [Azure Setup](docs/AZURE_FORM_RECOGNIZER_SETUP.md) |
| Credentials | [Setup Credentials](docs/SETUP_CREDENTIALS.md) |

### 🗺️ Планиране

| Документ | Описание |
|----------|----------|
| [План за модули](docs/MODULES_PLAN.md) | Подробен roadmap за всички модули |
| [Модулна диаграма](docs/MODULES_DIAGRAM_BG.md) | Визуализация на модулите и връзките |
| [Статус](docs/IMPLEMENTATION-STATUS.md) | Проверка на завършеност по модули |

---

## 👨‍💻 Разработка

### Структура на кода

```
cyberERP-open-bg/
├── apps/
│   ├── cyber_core/                 # Бизнес логика
│   │   └── lib/cyber_core/
│   │       ├── accounts/           # Tenants, Users
│   │       ├── accounting/         # VAT, SAF-T, Accounts
│   │       ├── inventory/          # Products, Warehouses
│   │       ├── sales/              # Invoices, POS
│   │       ├── purchase/           # Purchase Orders
│   │       └── settings/           # Company Settings
│   │
│   └── cyber_web/                  # Web интерфейс
│       ├── lib/cyber_web/
│       │   ├── live/              # LiveView страници
│       │   ├── components/        # UI компоненти
│       │   └── controllers/       # API контролери
│       └── assets/                 # Frontend (React, CSS, JS)
│
├── config/                         # Конфигурация
├── docs/                           # 📚 Документация
├── priv/                           # Private files (seeds, migrations)
└── rel/                            # Release конфигурация
```

### Полезни команди

```bash
# База данни
mix ecto.migrate      # Прилага миграции
mix ecto.rollback    # Отменя последната миграция
mix ecto.reset       # Нулира базата

# Генериране на код
mix phx.gen.context Core Product products name:string
mix phx.gen.live Inventory Product products name:string

# Тестове
mix test              # Всички тестове
mix test --cover      # С покритие

# Разработка
iex -S mix            # Интерактивна конзола
mix format            # Форматиране на код
mix credo             # Проверка на код качество
```

### API ендпоинти

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/api/auth/register` | POST | Регистрация |
| `/api/auth/login` | POST | Вход |
| `/api/auth/me` | GET | Текущ потребител |
| `/api/contacts` | GET/POST | Контрагенти |
| `/api/products` | GET/POST | Продукти |
| `/api/invoices` | GET/POST | Фактури |
| `/api/sales` | GET/POST | Продажби |
| `/api/accounting/*` | GET/POST | Счетоводни операции |

---

## 🔒 Multi-tenancy & Сигурност

### Multi-tenancy

Системата поддържа множество организации (tenants) чрез:

- **`X-Tenant-ID` header** за API заявки
- **Автоматична изолация** на данни per tenant
- **Префикс на схемата** в PostgreSQL
- **Споделени потребители** с различни роли per tenant

### Сигурност

- **RBAC** - Role-based access control
- **Row-level isolation** - Всички заявки филтрирани по `tenant_id`
- **JWT authentication** - Secure token-based auth
- **Ecto changeset validations** - Силна валидация на данни
- **Database constraints** - Unique constraints с `tenant_id`

---

## 📈 Статус на проекта

| Категория | Прогрес |
|-----------|---------|
| Архитектура и дизайн | ████████████████ 100% |
| База данни | ████████████████ 100% |
| API ендпоинти | ██████████████░░ 90% |
| Бизнес логика | ██████████████░░ 90% |
| LiveView интерфейси | █████████░░░░░░ 50% |
| Тестове | █████░░░░░░░░░░░ 30% |
| Документация | ████████████████ 100% |

**Общ прогрес:** ~76%

---

## 📞 Поддръжка

### Често срещани проблеми

**❌ Port 4000 е зает**
```bash
lsof -ti:4000 | xargs kill -9
```

**❌ Database connection error**
```bash
sudo systemctl restart postgresql
mix ecto.reset
```

**❌ Компилационни грешки**
```bash
mix clean
mix deps.get --all
mix compile
```

За повече информация: [Troubleshooting](docs/QUICK_START_BG.md#troubleshooting)

---

## 📄 Лиценз

Proprietary - Всички права запазени.

---

<div align="center">

**Made with ❤️ for the Bulgarian market 🇧🇬**

[📘 Пълна документация](docs/README.md) •
[🚀 Бърз старт](docs/QUICK_START_BG.md) •
[🏗️ Архитектура](docs/ARCHITECTURE_BG.md)

</div>
