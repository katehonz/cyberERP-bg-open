# AI Invoice Processing с Azure Form Recognizer

## Преглед

Cyber ERP интегрира Azure Form Recognizer за автоматично извличане на данни от PDF фактури. Системата използва prebuilt-invoice модел на Azure за OCR и структурирано извличане на полета.

## Архитектура

```
┌─────────────────┐
│  User Upload    │
│   (Browser)     │
└────────┬────────┘
         │ PDF Binary
         ▼
┌─────────────────────────┐
│  DocumentUploadLive     │
│  - Save to local disk   │
│  - Create DocumentUpload│
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  DocumentProcessor              │
│  - Send PDF to Azure            │
│  - Poll for results (async)     │
│  - Parse Azure response         │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  InvoiceExtractor               │
│  - Extract structured data      │
│  - Map to ExtractedInvoice      │
│  - Confidence scoring           │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  ExtractedInvoice (DB)          │
│  Status: pending_review         │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  ExtractedInvoiceLive           │
│  - PDF Preview (iframe)         │
│  - Review & Approve UI          │
│  - Edit extracted fields        │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Create SupplierInvoice/Invoice │
│  Status: approved → converted   │
└─────────────────────────────────┘
```

## Модули

### 1. DocumentUpload (Schema)
Записва metadata за качени PDF документи.

**Полета:**
- `tenant_id` - ID на tenant
- `original_filename` - Оригинално име на файла
- `local_path` - Път към файла на диска (`/uploads/documents/...`)
- `file_size` - Размер в bytes
- `file_type` - MIME type (`application/pdf`)
- `status` - `pending`, `processing`, `completed`, `failed`
- `azure_result` - Raw JSON резултат от Azure
- `processed_at` - Време на обработка

### 2. ExtractedInvoice (Schema)
Извлечени данни от фактури, очакващи одобрение.

**Полета:**
- `invoice_number`, `invoice_date`, `due_date`
- `vendor_name`, `vendor_address`, `vendor_vat_number`
- `customer_name`, `customer_address`, `customer_vat_number`
- `subtotal`, `tax_amount`, `total_amount`, `currency`
- `confidence_score` - Точност на извличане (0.0 - 1.0)
- `line_items` - JSONB array с редове
- `status` - `pending_review`, `approved`, `rejected`
- `raw_data` - Пълен Azure JSON response

### 3. AzureFormRecognizer (API Client)
HTTP клиент за комуникация с Azure Document Intelligence API.

**Функции:**
```elixir
# Стартира анализ на PDF
{:ok, operation_url} = AzureFormRecognizer.analyze_invoice_from_binary(tenant_id, pdf_binary)

# Проверява статус
{:ok, :running} = AzureFormRecognizer.get_analyze_result(tenant_id, operation_url)
{:ok, :succeeded, result} = AzureFormRecognizer.get_analyze_result(tenant_id, operation_url)

# Polling механизъм с retry
{:ok, result} = AzureFormRecognizer.poll_for_result(tenant_id, operation_url,
  max_attempts: 30,
  interval: 2000
)
```

**Configuration:**
API настройките се взимат от `integration_settings` таблица с fallback към Application config:
```elixir
config :cyber_core, CyberCore.DocumentProcessing.AzureFormRecognizer,
  endpoint: "https://your-resource.cognitiveservices.azure.com",
  api_key: "your-api-key",
  api_version: "2023-07-31"
```

### 4. InvoiceExtractor
Парсва Azure JSON response и извлича структурирани данни.

**Azure Field Mapping:**
```elixir
Azure Field          → ExtractedInvoice Field
─────────────────────────────────────────────
InvoiceId           → invoice_number
InvoiceDate         → invoice_date
DueDate             → due_date
VendorName          → vendor_name
VendorAddress       → vendor_address
VendorTaxId         → vendor_vat_number
CustomerName        → customer_name
CustomerAddress     → customer_address
CustomerTaxId       → customer_vat_number
SubTotal            → subtotal
TotalTax            → tax_amount
InvoiceTotal        → total_amount
Items               → line_items (array)
```

**Line Items Processing:**
```elixir
line_items = [
  %{
    description: "Счетоводни Услуги",
    quantity: Decimal.new("1"),
    unit_price: Decimal.new("300.00"),
    amount: Decimal.new("300.00"),
    tax: nil
  }
]
```

### 5. DocumentProcessor
Координира целия workflow на обработка.

**Main Function:**
```elixir
def process_single_pdf(tenant_id, pdf_binary, original_filename, opts \\ [])
```

**Options:**
- `:s3_bucket` - S3 bucket (optional)
- `:s3_key` - S3 key (optional)
- `:local_path` - Local file path
- `:invoice_type` - "sales" или "purchase"

**Flow:**
1. Create `DocumentUpload` record (status: pending)
2. Mark as processing
3. Send to Azure Form Recognizer
4. Poll for result (max 30 attempts × 2s = 60s timeout)
5. Extract invoice data with InvoiceExtractor
6. Create `ExtractedInvoice` record
7. Mark DocumentUpload as completed

**Error Handling:**
```elixir
# Azure analysis failed
{:error, "Azure analysis failed: timeout"}

# Extraction failed
{:error, "Failed to extract invoice data: invalid format"}
```

## UI Flow

### 1. Upload Page (`/documents/upload`)
- Live file upload с Phoenix.LiveView
- Drag & drop support
- Invoice type selector (Sales/Purchase)
- "ОБРАБОТИ ДОКУМЕНТИТЕ" бутон
- Progress tracking

### 2. Review Page (`/extracted-invoices`)
- Grid layout: 2/3 PDF preview + 1/3 form
- PDF показан в iframe
- Navigation: ← Назад / Напред →
- Editable fields за коригиране на грешки
- Status badge (обработен, одобрен, отхвърлен)
- Confidence score indicator:
  - 🟢 Green (≥90%) - Високо доверие
  - 🟡 Yellow (70-89%) - Средно доверие
  - 🔴 Red (<70%) - Ниско доверие

**Actions:**
- **Съхрани** - Одобрява и създава фактура
- **Запази OCR** - Запазва промени без одобрение
- **Изтрий** - Отхвърля извлечения документ

## Database Schema

### document_uploads
```sql
CREATE TABLE document_uploads (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  s3_bucket VARCHAR,
  s3_key VARCHAR,
  local_path VARCHAR,
  original_filename VARCHAR NOT NULL,
  file_size INTEGER,
  file_type VARCHAR,
  status VARCHAR NOT NULL DEFAULT 'pending',
  document_type VARCHAR,
  processed_at TIMESTAMP,
  error_message TEXT,
  azure_document_id VARCHAR,
  azure_result JSONB,
  extracted_invoice_id INTEGER,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### extracted_invoices
```sql
CREATE TABLE extracted_invoices (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  document_upload_id INTEGER REFERENCES document_uploads(id),
  invoice_type VARCHAR NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'pending_review',
  confidence_score DECIMAL(5,4),

  -- Invoice fields
  invoice_number VARCHAR,
  invoice_date DATE,
  due_date DATE,

  -- Parties
  vendor_name VARCHAR,
  vendor_address TEXT,
  vendor_vat_number VARCHAR,
  customer_name VARCHAR,
  customer_address TEXT,
  customer_vat_number VARCHAR,

  -- Financial
  subtotal DECIMAL(15,2),
  tax_amount DECIMAL(15,2),
  total_amount DECIMAL(15,2),
  currency VARCHAR DEFAULT 'BGN',

  -- Data
  line_items JSONB DEFAULT '[]',
  raw_data JSONB,

  -- Approval
  approved_by_id INTEGER REFERENCES users(id),
  approved_at TIMESTAMP,
  rejection_reason TEXT,

  -- Conversion
  converted_invoice_id INTEGER,
  converted_invoice_type VARCHAR,

  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

## File Storage

**Location:** `apps/cyber_web/priv/static/uploads/documents/`

**Naming Convention:** `{timestamp}_{original_filename}`
- Example: `1732382419_0000001108.pdf`

**Static Path:** `/uploads/documents/{filename}`

**Security:**
- Files се serve-ват като static assets
- Само authenticated users имат достъп до `/extracted-invoices`
- TODO: Implement per-tenant access control

## API Endpoints (Internal)

### DocumentProcessing Context
```elixir
# List uploads
DocumentProcessing.list_document_uploads(tenant_id, opts)

# Create upload
{:ok, upload} = DocumentProcessing.create_document_upload(attrs)

# Process PDF
{:ok, result} = DocumentProcessing.DocumentProcessor.process_single_pdf(
  tenant_id,
  pdf_binary,
  filename,
  invoice_type: "purchase",
  local_path: "/uploads/documents/file.pdf"
)

# List extracted invoices
invoices = DocumentProcessing.list_extracted_invoices(tenant_id, preloads: [:document_upload])

# Approve
{:ok, invoice} = DocumentProcessing.approve_extracted_invoice(invoice, user_id)

# Reject
{:ok, invoice} = DocumentProcessing.reject_extracted_invoice(invoice, user_id, "Грешна сума")
```

## Configuration

### Azure Form Recognizer Setup

1. **Създай Azure Resource:**
   ```bash
   az cognitiveservices account create \
     --name cyber-erp-form-recognizer \
     --resource-group cyber-erp \
     --kind FormRecognizer \
     --sku S0 \
     --location westeurope
   ```

2. **Get credentials:**
   ```bash
   az cognitiveservices account keys list \
     --name cyber-erp-form-recognizer \
     --resource-group cyber-erp
   ```

3. **Configure в Settings UI:**
   - Navigate to `/settings`
   - Tab: "Интеграции"
   - Service: "Azure Form Recognizer"
   - Endpoint: `https://your-resource.cognitiveservices.azure.com`
   - API Key: `your-api-key`

### Environment Variables (Development)
```elixir
# config/dev.exs
config :cyber_core, CyberCore.DocumentProcessing.AzureFormRecognizer,
  endpoint: System.get_env("AZURE_FORM_RECOGNIZER_ENDPOINT"),
  api_key: System.get_env("AZURE_FORM_RECOGNIZER_KEY"),
  api_version: "2023-07-31"
```

## Performance

### Azure API Limits
- **S0 Tier:** 15 requests/second
- **Processing Time:** 2-10 seconds per page
- **Max File Size:** 50 MB
- **Max Pages:** 2000 pages

### Optimization Tips
1. Use batch processing за multiple files
2. Cache Azure results in `azure_result` field
3. Async processing с GenServer/Oban jobs
4. PDF compression преди upload

## Error Handling

### Common Errors

**1. Azure Not Configured**
```elixir
{:error, "Azure Form Recognizer is not configured"}
```
**Fix:** Configure API credentials в Settings

**2. Invalid PDF**
```elixir
{:error, "API error: 400"}
```
**Fix:** Ensure PDF is valid, not password protected

**3. Polling Timeout**
```elixir
{:error, "Polling timeout after 30 attempts"}
```
**Fix:** Increase `max_attempts` or `interval`

**4. Extraction Failed**
```elixir
{:error, "No documents found in Azure result"}
```
**Fix:** Check PDF quality, may need manual entry

## Testing

### Manual Test
1. Upload test invoice PDF
2. Check `document_uploads` table
3. Wait for processing (watch logs)
4. Check `extracted_invoices` table
5. Review in `/extracted-invoices` page
6. Approve and verify invoice creation

### Test Files
Located in `test/fixtures/invoices/`:
- `bulgarian_invoice.pdf` - Standard BG invoice
- `eu_invoice.pdf` - EU invoice с VAT
- `multi_page.pdf` - Multiple pages
- `poor_quality.pdf` - Low quality scan

### Integration Test
```elixir
defmodule CyberCore.DocumentProcessing.IntegrationTest do
  use CyberCore.DataCase

  test "full invoice processing flow" do
    pdf_binary = File.read!("test/fixtures/invoices/bulgarian_invoice.pdf")

    # Process
    {:ok, result} = DocumentProcessor.process_single_pdf(
      1,
      pdf_binary,
      "test_invoice.pdf",
      invoice_type: "purchase",
      local_path: "/uploads/test.pdf"
    )

    # Verify extraction
    invoice = result.extracted_invoice
    assert invoice.invoice_number == "0000001108"
    assert invoice.vendor_name == "ИНФОРМЕЙТ ЕООД"
    assert invoice.total_amount == Decimal.new("300.00")

    # Approve
    {:ok, approved} = DocumentProcessing.approve_extracted_invoice(invoice, 1)
    assert approved.status == "approved"
  end
end
```

## Troubleshooting

### PDF не се показва
- Check `local_path` е записан в DB
- Verify файлът съществува на диска
- Check static paths включват `uploads`

### Azure connection failed
- Verify endpoint URL (no trailing slash)
- Check API key е valid
- Test connection: `curl` към Azure endpoint

### Low confidence scores
- Poor PDF quality → rescan at higher DPI
- Handwritten text → Azure може да не разпознае
- Non-standard layout → manual review needed

### Line items not extracted
- Azure може да не намери таблица
- Manual entry needed
- Consider OCR preprocessing

## Интелигентно Мапиране (Smart Mapping)

### Contact-Based Product Mapping

**Проблем:** Всеки доставчик използва своя номенклатура за продукти.

**Решение:** Таблица за мапиране: `contact_id + vendor_description → product_id`

#### Database Schema

```sql
CREATE TABLE contact_product_mappings (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  contact_id INTEGER NOT NULL,
  vendor_description VARCHAR NOT NULL,
  product_id INTEGER REFERENCES products(id),
  times_seen INTEGER DEFAULT 1,
  confidence DECIMAL(3,2) DEFAULT 1.00,
  created_by_id INTEGER REFERENCES users(id),
  last_seen_at TIMESTAMP,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(tenant_id, contact_id, vendor_description)
);
```

#### Workflow

1. **При обработка на фактура:**
   - За всеки line item търсим existing mapping
   - Ако mapping съществува → show suggestion с confidence badge
   - При одобрение → increment `times_seen`, update `last_seen_at`

2. **Learning System:**
   - `times_seen = 1` → 🟡 Ново мапиране
   - `times_seen >= 3` → 🟢 Проверено мапиране
   - `confidence` score базиран на history

3. **UI:**
   ```
   Line Item: "Счетоводни услуги декември 2024"
   └─ 🟢 Предлаган продукт: "Абонаментни счетоводни услуги" (5x seen)
      [Запази мапинга]
   ```

#### API Functions

```elixir
alias CyberCore.Inventory.ProductMapper

# Търсене на мапинг
{:ok, product} = ProductMapper.find_mapping(contact_id, "Счетоводни услуги", tenant_id)

# Запазване на мапинг
{:ok, mapping} = ProductMapper.save_mapping(
  contact_id,
  "Счетоводни услуги",
  product_id,
  tenant_id
)

# List all mappings за контрагент
mappings = ProductMapper.list_mappings_for_contact(contact_id, tenant_id)
```

### Contact-Based Bank Account Mapping

**Проблем:** При плащания трябва да знаем банковите сметки на доставчиците.

**Решение:** Автоматично извличане на IBAN от фактури за покупки.

**⚠️ ВАЖНО:** Използва се САМО за ПОКУПКИ (supplier invoices), НЕ за продажби!

#### Database Schema

```sql
CREATE TABLE contact_bank_accounts (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL,
  contact_id INTEGER NOT NULL REFERENCES contacts(id),
  iban VARCHAR,
  bic VARCHAR,
  bank_name VARCHAR,
  account_number VARCHAR,
  currency VARCHAR DEFAULT 'BGN',
  is_primary BOOLEAN DEFAULT false,
  is_verified BOOLEAN DEFAULT false,
  first_seen_at TIMESTAMP NOT NULL,
  last_seen_at TIMESTAMP NOT NULL,
  times_seen INTEGER DEFAULT 1,
  notes TEXT,
  created_by_id INTEGER REFERENCES users(id),
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(tenant_id, contact_id, iban)
);
```

#### Workflow - Покупки

1. **Извличане от supplier invoice:**
   - Azure Form Recognizer извлича `vendor_bank_iban`, `vendor_bank_bic`, `vendor_bank_name`
   - Полета добавени към `extracted_invoices`:
     ```elixir
     field :vendor_bank_account, :string
     field :vendor_bank_iban, :string
     field :vendor_bank_bic, :string
     field :vendor_bank_name, :string
     ```

2. **При одобрение на фактура:**
   - Записваме IBAN в `contact_bank_accounts`
   - Ако IBAN вече съществува → увеличаваме `times_seen`
   - Ако е първа сметка → маркираме като `is_primary = true`

3. **Автоматично матчване при плащане:**
   - Банков import дава `bank_transaction` с `correspondent_account` (IBAN на доставчика)
   - Системата търси този IBAN в `contact_bank_accounts`
   - Намира контрагента автоматично
   - Предлага неплатени supplier invoices за матчване
   - ✅ Автоматичен reconciliation!

#### Примери

```elixir
alias CyberCore.Contacts.ContactBankAccountMapper

# От supplier invoice (покупка) извличаме:
invoice = %ExtractedInvoice{
  invoice_type: "purchase",
  vendor_name: "ИНФОРМЕЙТ ЕООД",
  vendor_bank_iban: "BG80BNBG96611020345678"
}

# При одобрение запазваме:
{:ok, bank_account} = ContactBankAccountMapper.save_bank_account_from_invoice(
  contact_id,
  "BG80BNBG96611020345678",
  tenant_id,
  bic: "BNBGBGSD",
  bank_name: "БНБ"
)

# При импорт на bank_transaction (ИЗХОДЯЩО плащане):
transaction = %{
  amount: -1200.00,  # минус = изходящо
  correspondent_account: "BG80BNBG96611020345678"
}

# Намираме контрагента:
{:ok, contact} = ContactBankAccountMapper.find_contact_by_iban(
  "BG80BNBG96611020345678",
  tenant_id
)
# → %Contact{name: "ИНФОРМЕЙТ ЕООД", is_supplier: true}
```

#### Не се използва за продажби!

```elixir
# Sales invoice (продажба) - НЕ извличаме customer_bank_iban
invoice = %ExtractedInvoice{
  invoice_type: "sales",
  customer_name: "SOME CLIENT Ltd"
  # ❌ customer_bank_iban: НЕ ИЗВЛИЧАМЕ!
}

# При получаване на плащане:
transaction = %{
  amount: +1500.00,  # плюс = входящо
  our_account: "BG12BANK..."  # ← Наша сметка от bank_accounts
  # correspondent_account: може да няма или да е различна
}

# → Матчваме по invoice_number в описанието
# → Матчваме по amount
# → Използваме НАШИТЕ bank_accounts, не contact_bank_accounts!
```

#### UI Display

```
┌─────────────────────────────────────────────────┐
│ Банкова сметка на доставчика                    │
├─────────────────────────────────────────────────┤
│ IBAN: BG80BNBG96611020345678                    │
│ BIC:  BNBGBGSD                                  │
│ Bank: БНБ                                       │
│                                                 │
│ Status: ✓ Позната сметка (5x) ★ Главна         │
└─────────────────────────────────────────────────┘
```

**Status badges:**
- 🟢 `✓ Pozната smetka (5x)` - Known bank account, seen 5 times
- 🟡 `• Нова sметка` - New bank account (first time)
- 🔴 `⚠ Друг kontakt!` - Warning: IBAN belongs to different contact
- ⭐ `★ Glavna` - Primary account

#### API Functions

```elixir
alias CyberCore.Contacts.ContactBankAccountMapper

# Запазване на банкова сметка от фактура
{:ok, bank_account} = ContactBankAccountMapper.save_bank_account_from_invoice(
  contact_id,
  "BG80BNBG96611020345678",
  tenant_id,
  bic: "BNBGBGSD",
  bank_name: "БНБ",
  user_id: user_id
)

# Намиране на контрагент по IBAN (при bank import)
contact = ContactBankAccountMapper.find_contact_by_iban(
  "BG80BNBG96611020345678",
  tenant_id
)

# List all accounts за контрагент
accounts = ContactBankAccountMapper.list_bank_accounts_for_contact(
  contact_id,
  tenant_id
)

# Получаване на главна сметка
primary = ContactBankAccountMapper.get_primary_bank_account(
  contact_id,
  tenant_id
)

# Маркиране като главна
{:ok, _} = ContactBankAccountMapper.set_as_primary(
  bank_account_id,
  contact_id,
  tenant_id
)

# Верифициране след успешно плащане
{:ok, _} = ContactBankAccountMapper.verify_bank_account(bank_account_id)
```

#### Tracking Fields

- `times_seen` - Колко пъти сме видели тази сметка във фактури
- `first_seen_at` - Кога за първи път сме я видели
- `last_seen_at` - Последен път видяна
- `is_verified` - Дали е потвърдена след успешно плащане
- `is_primary` - Главна сметка на контрагента

## UI Redesign - Table View с Modal Editor

**Променено:** PDF preview премахнат (user работи на два монитора)

### Table View (`/extracted-invoices`)

```
┌────────────────────────────────────────────────────────────────────┐
│ СКАНИРАНИ ФАКТУРИ (5)                             [+ Качи нови]     │
├─────┬──────────┬───────────────┬────────────┬────────────┬────────┤
│ Тип │ Номер    │ Доставчик     │ Сума       │ Дата       │ Статус │
├─────┼──────────┼───────────────┼────────────┼────────────┼────────┤
│ 🛒  │ 0001108  │ ИНФОРМЕЙТ ЕОО │ 300.00 BGN │ 2024-11-22 │ 🟡     │
│ 🛒  │ 0001109  │ ЕВРОТРЕЙД ООД │ 1,200.00 € │ 2024-11-21 │ 🟢     │
│ 📤  │ INV-2024 │ CLIENT Ltd    │ 500.00 BGN │ 2024-11-20 │ ✓      │
└─────┴──────────┴───────────────┴────────────┴────────────┴────────┘
```

**Icons:**
- 🛒 Purchase (Покупка)
- 📤 Sales (Продажба)

**Status:**
- 🟡 `pending_review` - Pending Review
- 🟢 `approved` - Одобрена
- 🔴 `rejected` - Отхвърлена

**Click row** → Opens modal editor

### Modal Editor

**Показва се при click на row в таблицата.**

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⬅ НАЗАД                   ФАКТУРА #0001108                  НАПРЕД ➡ │
│                                                              [× CLOSE] │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  [📄 VIEW PDF]  ← External link, opens in new window/monitor         │
│                                                                        │
│  ┌─────────────────────── ОСНОВНИ ДАННИ ──────────────────────────┐  │
│  │ Тип: [🛒 Покупка ▼]           Номер: [0001108]                 │  │
│  │ Дата: [2024-11-22]            Падеж: [2024-12-22]              │  │
│  │ Сума: [300.00]                Валута: [BGN ▼]                  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌─────────────────────── ДОСТАВЧИК ──────────────────────────────┐  │
│  │ 🔍 ИНФОРМЕЙТ ЕООД                        [✓ Позната] (23x)     │  │
│  │ ДДС: BG123456789                                                │  │
│  │ Адрес: София, бул. Витоша 1                                     │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌─────────────────── БАНКОВА СМЕТКА ─────────────────────────────┐  │
│  │ IBAN: BG80BNBG96611020345678                                    │  │
│  │ BIC:  BNBGBGSD                                                  │  │
│  │ Bank: БНБ                                                       │  │
│  │                                                                 │  │
│  │ ✓ Pozната sметка (5x) ★ Главна                                 │  │
│  │ 💡 При плащане системата ще намери доставчика автоматично       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
  │  ┌─────────────────────── АРТИКУЛИ ───────────────────────────────┐  │
  │  │                                                                  │  │
  │  │  Описание: Счетоводни услуги декември                           │  │
  │  │  🟢 Предлаган: Абонаментни счетоводни услуги (5x)               │  │
  │  │  Кол: 1  Цена: 300.00  Сума: 300.00                             │  │
  │  │                                                                  │  │
  │  │  [+ Създай нов продукт]                                         │  │
  │  │                                                      [+ Добави]  │  │
  │  └────────────────────────────────────────────────────────────────┘  ││                                                                        │
│  ┌─────────────────────── ФИНАНСОВИ ──────────────────────────────┐  │
│  │ Основа:    300.00 BGN                                           │  │
│  │ ДДС (20%):  60.00 BGN                                           │  │
│  │ Общо:      360.00 BGN                                           │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  [💾 СЪХРАНИ И ОДОБРИ]  [📝 Запази OCR]  [🗑 Изтрий]                │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

**Features:**
- ⬅ НАЗАД / НАПРЕД ➡ - Navigate between invoices
- [📄 VIEW PDF] - Opens PDF in new window (for second monitor)
- Contact suggestions with `(23x seen)` indicator
- Bank account display with status badges
- Product mapping suggestions with confidence
- All fields editable
- Actions: Съхрани (approve), Запази OCR (save without approval), Изтрий (reject)

## Known Issues

### Dual Currency (EUR + BGN) Invoices

**Проблем:** В момента в България фактурите се пишат едновременно в Евро и лева, което объркva Azure AI.

**Пример:**
```
Сума: 100.00 EUR (195.58 BGN)
```

**Azure response:**
```json
{
  "InvoiceTotal": {
    "value": 195.58,
    "confidence": 0.75
  }
}
```

Azure не знае коя сума е правилната, може да избере BGN вместо EUR.

**Timeline:**
- **До датата на въвеждане на еврото:** Всички фактури в лева (само BGN)
- **След датата на въвеждане:** Всички фактури в евро (само EUR)
- **Сега (преходен период):** Двойна валута объркva AI

**Workaround:**
- Тествай с чисти фактури преди 08-2025
- Manual review на extracted сума
- Confidence score ще е по-нисък

**Fix (future):**
- Custom Azure model trained on Bulgarian invoices
- Post-processing rule: ако има EUR и BGN → вземи EUR
- Regex detection на pattern "X.XX EUR (Y.YY BGN)"

## Roadmap

### ✅ Completed
- [x] Table view с modal editor
- [x] Contact-based product mapping
- [x] Contact-based bank account mapping
- [x] Learning system (times_seen tracking)
- [x] UI status indicators and confidence badges
- [x] Invoice converter (ExtractedInvoice → SupplierInvoice/Invoice)
- [x] Contact auto-creation from VAT number (VIES validation)
- [x] Keyboard shortcuts (Esc, ←/→, Ctrl+Enter)
- [x] Bulk operations (approve all, delete all)

### Short-term (Next sprint)
- [ ] Email integration (receive invoices via email)
- [ ] Bank transaction auto-matching by correspondent_account
- [ ] OCR quality improvements
- [ ] Multi-language support

### Mid-term (1-2 months)
- [ ] Mobile app scanning
- [ ] AI duplicate detection
- [ ] Custom Azure model for Bulgarian invoices

### Long-term (3+ months)
- [ ] Accounting software exports (SAF-T)

## Resources

- [Azure Form Recognizer Docs](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/)
- [Prebuilt Invoice Model](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/concept-invoice)
- [Phoenix LiveView Uploads](https://hexdocs.pm/phoenix_live_view/uploads.html)
- [Phoenix LiveView Modals](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#live_component/1)

---

**Last Updated:** 2025-11-24
**Version:** 2.0
**Author:** Claude & DVG
