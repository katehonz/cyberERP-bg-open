# Azure Form Recognizer Интеграция

## Общ Преглед

Интеграцията с Azure Form Recognizer автоматизира извличането на данни от фактури директно от браузъра към Azure AI и създава записи в ERP системата.

## Архитектура

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────────┐
│  Browser    │────▶│ ERP System   │────▶│ Azure Form          │
│ (PDF Upload)│     │ (LiveView)   │     │ Recognizer API      │
└─────────────┘     └──────┬───────┘     └──────────────────────┘
                           │                       │
                           │     JSON Response     │
                           │◀──────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ ExtractedInvoice │
                    │ (Pending Review) │
                    └──────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ User Approval│
                    └──────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Final Invoice│
                    │ (Sales/      │
                    │  Purchase)   │
                    └──────────────┘
```

**Workflow:**
1. Потребителят качва PDF фактура през браузъра
2. ERP системата изпраща PDF директно към Azure Form Recognizer
3. Azure извлича данните и връща JSON резултат
4. Данните се записват като ExtractedInvoice със статус "pending_review"
5. Потребителят прегледа и одобрява/отхвърля
6. След одобрение се създава финална фактура

## Компоненти

### 1. База Данни

Две нови таблици:

- **`document_uploads`** - Качени документи за обработка
- **`extracted_invoices`** - Извлечени данни, очакващи одобрение

### 2. Модули

```
apps/cyber_core/lib/cyber_core/document_processing/
├── document_upload.ex          # Ecto схема за качени документи
├── extracted_invoice.ex        # Ecto схема за извлечени фактури
├── azure_form_recognizer.ex    # Azure API клиент
├── invoice_extractor.ex        # Парсване на Azure резултати
└── document_processor.ex       # Главен workflow orchestrator
```

### 3. Workflow - Upload от браузъра

```elixir
# 1. Потребителят качва PDF през UI (/documents/upload)
# 2. PDF се изпраща директно към Azure Form Recognizer
# 3. Резултатът създава ExtractedInvoice записи със статус "pending_review"

# 4. Потребителят прегледа и одобрява в UI
alias CyberCore.DocumentProcessing

extracted_invoice = DocumentProcessing.get_extracted_invoice!(tenant_id, id)
DocumentProcessing.approve_extracted_invoice(extracted_invoice, user_id)

# 5. След одобрение, създава се финална фактура
# (това трябва да се имплементира)
```

## Настройка

### 1. Azure Form Recognizer

#### Създаване на Resource

1. Влезте в [Azure Portal](https://portal.azure.com)
2. Create a resource → AI + Machine Learning → Form Recognizer
3. Изберете subscription и resource group
4. Изберете region (препоръчително: West Europe)
5. Изберете pricing tier (F0 за тестване, S0 за production)

#### Вземане на Credentials

```bash
# Endpoint
https://YOUR_RESOURCE_NAME.cognitiveservices.azure.com/formrecognizer

# API Key (Keys and Endpoint → Key 1)
YOUR_API_KEY_HERE
```

### 2. Конфигурация в ERP системата

Отворете настройките на системата:

```
http://localhost:4000/settings
```

В секцията **"AI и Cloud Интеграции"** попълнете:

- **Azure Endpoint**: `https://YOUR_RESOURCE_NAME.cognitiveservices.azure.com/`
- **API Key**: Вашият API key от Azure Portal

Натиснете **"Запази Azure Form Recognizer"**

### 3. Миграции

```bash
mix ecto.migrate
```

## Използване

### Използване през UI (препоръчително)

#### 1. Upload на фактури

Отворете страницата за upload:
```
http://localhost:4000/documents/upload
```

Стъпки:
1. Изберете тип фактура: **Покупки** или **Продажби**
2. Качете PDF файл (drag & drop или "Изберете файлове")
3. Натиснете **"Обработи с AI"**
4. Изчакайте обработката (10-20 секунди)

#### 2. Преглед на извлечените данни

Отворете страницата с резултати:
```
http://localhost:4000/extracted-invoices
```

Функции:
- Преглед на извлечените данни (номер, доставчик, дата, сума, ДДС)
- Confidence score - точност на извличането
- Навигация напред/назад между фактурите
- Бутони: **Съхрани** (одобри), **Запази OCR**, **Изтрий** (отхвърли)

### Програмен достъп

```elixir
alias CyberCore.DocumentProcessing

# Списък на извлечени фактури, очакващи преглед
invoices = DocumentProcessing.list_extracted_invoices(
  tenant_id,
  filters: %{status: "pending_review"}
)

# Преглед на конкретна фактура
invoice = DocumentProcessing.get_extracted_invoice!(tenant_id, invoice_id)

# Одобрение
{:ok, approved} = DocumentProcessing.approve_extracted_invoice(invoice, user_id)

# Отхвърляне
{:ok, rejected} = DocumentProcessing.reject_extracted_invoice(
  invoice,
  user_id,
  "VAT number is incorrect"
)
```

## UI Компоненти ✅

LiveView компоненти са **имплементирани и готови за използване**:

### 1. **Upload на фактури** ✅ (`/documents/upload`)

**Достъп:** Sidebar → AI и Cloud → 🤖 Обработка на документи

**Функционалности:**
- ✅ Drag & drop zone за PDF фактури
- ✅ До 10 файла едновременно (max 10MB всеки)
- ✅ Progress bar при качване
- ✅ Визуална индикация на качени файлове
- ✅ Бутон "Обработи с AI"
- ✅ Резултати в реално време
- ✅ Автоматична проверка за Azure конфигурация

**URL:** http://localhost:4000/documents/upload

**Файл:** `apps/cyber_web/lib/cyber_web/live/document_upload_live/index.ex`

### 2. **Преглед на извлечени данни** ✅ (`/extracted-invoices`)

**Достъп:** Sidebar → AI и Cloud → ✓ Извлечени фактури

**Функционалности:**
- ✅ Таблица с всички извлечени фактури
- ✅ Статистики в реално време (Изчакващи, Одобрени, Отхвърлени)
- ✅ Confidence score с цветна индикация:
  - Зелено: ≥90% точност
  - Жълто: 70-89% точност
  - Червено: <70% точност
- ✅ Статус индикатори
- ✅ Бутони "Одобри" / "Отхвърли"
- ✅ Детайли: номер, доставчик, дата, сума

**URL:** http://localhost:4000/extracted-invoices

**Файл:** `apps/cyber_web/lib/cyber_web/live/extracted_invoice_live/index.ex`

### 3. **Настройки на интеграции** ✅ (`/settings`)

**Достъп:** Sidebar → Система → Настройки → AI и Cloud Интеграции

**Azure Form Recognizer секция:**
- ✅ Input за Azure Endpoint
- ✅ Password поле за API Key
- ✅ Индикатор за статус
- ✅ Валидация
- ✅ Записване в базата данни

**Забележка:** PDF файловете се обработват директно от браузъра към Azure - не е необходимо S3 storage.

**URL:** http://localhost:4000/settings

**Файл:** `apps/cyber_web/lib/cyber_web/live/settings_live/index.ex`

### 4. **Навигация** ✅

Нова секция в sidebar:
```
AI и Cloud
├── 🤖 Обработка на документи  (/documents/upload)
└── ✓  Извлечени фактури       (/extracted-invoices)
```

**Файл:** `apps/cyber_web/lib/cyber_web/components/layouts/app.html.heex`

## Следващи Стъпки (Опционални)

### TODO: Конверсия към финални фактури

След одобрение, трябва да се създава финална фактура:

```elixir
defmodule CyberCore.DocumentProcessing.InvoiceConverter do
  def convert_to_supplier_invoice(extracted_invoice) do
    # Mapва ExtractedInvoice → SupplierInvoice
    # Създава SupplierInvoice и SupplierInvoiceLines
    # Маркира ExtractedInvoice като converted
  end

  def convert_to_sales_invoice(extracted_invoice) do
    # Mapва ExtractedInvoice → Invoice
    # Създава Invoice и InvoiceLines
    # Маркира ExtractedInvoice като converted
  end
end
```

### TODO: Background Jobs

За production, препоръчително е обработката да се прави асинхронно:

```elixir
# Използвайте Oban за job queue
defmodule CyberCore.Workers.ProcessDocumentWorker do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"document_upload_id" => id}}) do
    document = DocumentProcessing.get_document_upload!(id)
    # Process document...
  end
end
```

## Тестване

### Тестване на Azure интеграцията

```bash
iex -S mix

# Проверка на Azure credentials
iex> alias CyberCore.DocumentProcessing.AzureFormRecognizer
iex> pdf = File.read!("test/fixtures/sample_invoice.pdf")
iex> {:ok, operation_url} = AzureFormRecognizer.analyze_invoice_from_binary(pdf)
iex> {:ok, result} = AzureFormRecognizer.poll_for_result(operation_url)
```

### Тестване през UI

1. Отворете http://localhost:4000/documents/upload
2. Качете тестова PDF фактура
3. Натиснете "Обработи с AI"
4. Проверете резултатите в http://localhost:4000/extracted-invoices

## Цени

### Azure Form Recognizer

- **F0 (Free)**: 500 страници/месец
- **S0 (Standard)**:
  - 0-1M страници: $1.50 за 1000 страници
  - 1M-10M страници: $0.60 за 1000 страници

## Полезни Линкове

- [Azure Form Recognizer Docs](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/)
- [Azure Prebuilt Invoice Model](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/concept-invoice)
