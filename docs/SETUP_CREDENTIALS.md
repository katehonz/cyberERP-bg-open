# Настройка на Credentials в Базата Данни

## Обща Информация

Credentials за Azure Form Recognizer и S3 се съхраняват **в базата данни** (таблица `integration_settings`), а не в `.env` файлове.

Това позволява:
- ✅ Различни настройки за различни tenants
- ✅ Лесна промяна през UI (в бъдеще)
- ✅ Сигурно съхранение
- ✅ Enable/Disable интеграции без изтриване на credentials

---

## Вашите Azure Credentials

От JSON файловете в `FormRecognizerCreate-20251122221711/`:

```
Resource Name: cybererp
Location: West Europe (westeurope)
Endpoint: https://cybererp.cognitiveservices.azure.com/
API Key: (трябва да го вземете от Azure Portal)
```

### Как да вземете API Key:

1. Отворете https://portal.azure.com
2. Resource Groups → `cyber-erp`
3. Кликнете на `cybererp`
4. Лявото меню → **"Ключи и конечная точка"** (Keys and Endpoint)
5. Копирайте **KEY 1**

---

## Запис на Credentials в Базата Данни

### Вариант 1: През IEx Console

```bash
# Стартирайте IEx
iex -S mix

# Запишете Azure Form Recognizer настройки
alias CyberCore.Settings

{:ok, azure_setting} = Settings.upsert_azure_form_recognizer(
  1,  # tenant_id
  "https://cybererp.cognitiveservices.azure.com/",
  "ТУК_ВАШИЯ_AZURE_API_KEY"
)

# Запишете S3 (Hetzner) настройки
{:ok, s3_setting} = Settings.upsert_s3_storage(
  1,  # tenant_id
  "ТУК_HETZNER_ACCESS_KEY",
  "ТУК_HETZNER_SECRET_KEY",
  "fsn1.your-objectstorage.com",  # или вашият S3 host
  "cyber-invoices"  # име на bucket
)

# Проверка
Settings.list_integration_settings(1)
```

### Вариант 2: През seed скрипт

Създайте файл `priv/repo/seeds/integration_settings.exs`:

```elixir
alias CyberCore.Settings

# Azure Form Recognizer
Settings.upsert_azure_form_recognizer(
  1,
  "https://cybererp.cognitiveservices.azure.com/",
  System.get_env("AZURE_API_KEY") || "YOUR_API_KEY_HERE"
)

# S3 Hetzner
Settings.upsert_s3_storage(
  1,
  System.get_env("HETZNER_ACCESS_KEY") || "YOUR_ACCESS_KEY",
  System.get_env("HETZNER_SECRET_KEY") || "YOUR_SECRET_KEY",
  System.get_env("HETZNER_S3_HOST") || "fsn1.your-objectstorage.com",
  System.get_env("HETZNER_S3_BUCKET") || "cyber-invoices"
)

IO.puts("✅ Integration settings created successfully!")
```

Изпълнете:
```bash
mix run priv/repo/seeds/integration_settings.exs
```

---

## Използване

### Проверка дали credentials работят

```elixir
iex> alias CyberCore.DocumentProcessing.AzureFormRecognizer
iex> config = AzureFormRecognizer.get_tenant_config(1)
%{
  endpoint: "https://cybererp.cognitiveservices.azure.com/",
  api_key: "***",
  api_version: "2024-11-30"
}

# Тест с реална фактура
iex> pdf = File.read!("test_invoice.pdf")
iex> {:ok, operation_url} = AzureFormRecognizer.analyze_invoice_from_binary(pdf)
iex> {:ok, result} = AzureFormRecognizer.poll_for_result(operation_url)
```

### Обработка на документи от S3

```elixir
alias CyberCore.DocumentProcessing.DocumentProcessor

# Обработва файлове от S3 за tenant 1
DocumentProcessor.process_files_from_s3(
  1,  # tenant_id
  ["invoices/invoice_001.pdf", "invoices/invoice_002.pdf"],
  bucket: "cyber-invoices",
  invoice_type: "purchase"
)
```

---

## Управление на Credentials

### Преглед на настройки

```elixir
# Всички интеграции за tenant
Settings.list_integration_settings(1)

# Само Azure настройки
Settings.list_integration_settings(1, integration_type: "azure_form_recognizer")

# Конкретна настройка
{:ok, setting} = Settings.get_integration_setting(1, "azure_form_recognizer", "default")
```

### Актуализация

```elixir
{:ok, setting} = Settings.get_integration_setting(1, "azure_form_recognizer", "default")

Settings.update_integration_setting(setting, %{
  config: %{
    "endpoint" => "https://cybererp.cognitiveservices.azure.com/",
    "api_key" => "NEW_API_KEY",
    "api_version" => "2024-11-30"
  }
})
```

### Enable/Disable интеграция

```elixir
# Disable Azure интеграция (без да изтриваме credentials)
Settings.toggle_integration(1, "azure_form_recognizer")

# Enable отново
Settings.toggle_integration(1, "azure_form_recognizer")

# Проверка
Settings.integration_enabled?(1, "azure_form_recognizer")
#=> true
```

---

## Структура на Таблицата

```sql
integration_settings
├── id (integer)
├── tenant_id (integer) - за мулти-тенант поддръжка
├── integration_type (string) - "azure_form_recognizer", "s3_storage", и др.
├── name (string) - "default" или друго име за множество настройки
├── enabled (boolean) - дали е активна интеграцията
├── config (jsonb) - credentials и други настройки
├── inserted_at (datetime)
└── updated_at (datetime)

UNIQUE INDEX: (tenant_id, integration_type, name)
```

### Примерен config за Azure:

```json
{
  "endpoint": "https://cybererp.cognitiveservices.azure.com/",
  "api_key": "your-api-key-here",
  "api_version": "2024-11-30"
}
```

### Примерен config за S3:

```json
{
  "access_key_id": "your-access-key",
  "secret_access_key": "your-secret-key",
  "host": "fsn1.your-objectstorage.com",
  "bucket": "cyber-invoices",
  "scheme": "https://",
  "port": 443,
  "region": "eu-central"
}
```

---

## Бърз старт скрипт

Направете това **веднъж** за да настроите credentials:

```bash
# 1. Влезте в IEx
iex -S mix

# 2. Заредете Azure API key от Azure Portal
azure_api_key = "КОПИРАЙТЕ_ОТ_AZURE_PORTAL"

# 3. Запишете Azure настройки
CyberCore.Settings.upsert_azure_form_recognizer(1, "https://cybererp.cognitiveservices.azure.com/", azure_api_key)

# 4. Ако имате S3 credentials
CyberCore.Settings.upsert_s3_storage(1, "access_key", "secret_key", "host", "bucket")

# 5. Проверка
CyberCore.Settings.list_integration_settings(1)
```

---

## Следващи Стъпки

1. **Вземете Azure API Key** от Portal
2. **Запишете credentials** в базата
3. **Тествайте** с примерна фактура
4. **Създайте UI** за управление на settings (опционално, но препоръчително)

---

## Сигурност

⚠️ **ВАЖНО:**
- Никога не commit-вайте API keys в Git
- API keys се съхраняват в базата данни (може да се добави encryption)
- Използвайте `.env` файлове само за development, а за production - базата данни
