# Автоматична номерация на документи

## Съдържание

1. [Общ преглед](#общ-преглед)
2. [Формат на номерацията](#формат-на-номерацията)
3. [Типове номерации](#типове-номерации)
4. [Имплементация](#имплементация)
5. [Настройки](#настройки)
6. [API използване](#api-използване)
7. [Примери](#примери)
8. [FAQ](#faq)

---

## Общ преглед

Системата осигурява **автоматична номерация** на документи за продажби според изискванията на **ППЗДДС (Правилник за прилагане на ЗДДС)**.

### Ключови характеристики

- ✅ **10-цифрена номерация** с водещи нули (например: 0000000001)
- ✅ **Отделни номерации** за различни типове документи
- ✅ **Thread-safe** генериране с database locks
- ✅ **Конфигурируеми** начални стойности
- ✅ **Автоматично генериране** при създаване на нов документ

---

## Формат на номерацията

### Стандартен формат

Всеки номер е **точно 10 цифри** с водещи нули:

```
0000000001  ← Първи документ
0000000002  ← Втори документ
0000000123  ← Сто двадесет и трети документ
0000999999  ← Документ номер 999,999
9999999999  ← Максимален номер
```

### Правна основа

Според **ППЗДДС**, полето "Номер на документ" в дневниците за продажби и покупки трябва да е:
- **Символен тип** (string)
- **Ляво изравнен**
- **Без водещи нули при попълване в NAP файлове** (но системата ги съхранява за вътрешна употреба)

---

## Типове номерации

Системата поддържа **две отделни номерации**:

### 1. Номерация за фактури за продажби

**Използва се за:**
- Фактури (код 01)
- Дебитни известия (код 02)
- Кредитни известия (код 03)
- Регистри на стоки (код 04)
- Митнически документи (код 07)
- Фактури при касова отчетност (кодове 11, 12, 13)
- Кредитни известия по чл. 126б (код 23)
- Отчети (кодове 81, 82, 83, 84, 85)
- Протоколи за безвъзмездно предоставяне (код 95)

**Настройка:** `sales_invoice_next_number` в Company Settings

**Стойност по подразбиране:** 1

### 2. Номерация за протоколи ВОП

**ВОП = Вътреобщностно придобиване**

**Използва се за:**
- Протокол или друг документ (код 09)
- Протокол по чл. 126б, ал. 2 и 7 (код 29)
- Протокол за начисляване на ДДС за горива (код 50)
- Протокол за изискуемия данък по чл. 151в, ал. 3 (код 91)
- Протокол за данъчния кредит по чл. 151г, ал. 8 (код 92)
- Протокол по чл. 151в, ал. 7 - не прилага спец. режим (код 93)
- Протокол по чл. 151в, ал. 7 - прилага спец. режим (код 94)

**Настройка:** `vop_protocol_next_number` в Company Settings

**Стойност по подразбиране:** 1

---

## Имплементация

### Backend структура

#### 1. DocumentNumbering модул

**Файл:** `apps/cyber_core/lib/cyber_core/settings/document_numbering.ex`

**Публични функции:**

```elixir
# Генерира следващ номер за фактура за продажба
{:ok, "0000000001"} = DocumentNumbering.next_sales_invoice_number(tenant_id)

# Генерира следващ номер за протокол ВОП
{:ok, "0000000001"} = DocumentNumbering.next_vop_protocol_number(tenant_id)

# Форматира число в 10-цифрен формат
"0000000123" = DocumentNumbering.generate_number(123)

# Валидира формата на номер
true = DocumentNumbering.valid_number?("0000000001")
false = DocumentNumbering.valid_number?("123")

# Връща текущата стойност без да я увеличава
{:ok, 42} = DocumentNumbering.current_counter(tenant_id, :sales_invoice_next_number)

# Ресетва брояч (използвайте внимателно!)
{:ok, _} = DocumentNumbering.reset_counter(tenant_id, :sales_invoice_next_number, 1000)
```

#### 2. Sales модул интеграция

**Файл:** `apps/cyber_core/lib/cyber_core/sales.ex`

**Автоматично генериране:**

```elixir
defp maybe_generate_invoice_number(attrs) do
  tenant_id = attrs["tenant_id"] || attrs[:tenant_id]
  vat_document_type = attrs["vat_document_type"] || attrs[:vat_document_type]

  if tenant_id do
    case generate_invoice_number_by_type(tenant_id, vat_document_type) do
      {:ok, number} -> Map.put(attrs, "invoice_no", number)
      _ -> attrs
    end
  else
    attrs
  end
end

# Определя кой тип номерация да използва
defp generate_invoice_number_by_type(tenant_id, vat_document_type)
    when vat_document_type in ["09", "29", "50", "91", "92", "93", "94", "95"] do
  # Протоколи ВОП - отделна номерация
  DocumentNumbering.next_vop_protocol_number(tenant_id)
end

defp generate_invoice_number_by_type(tenant_id, _vat_document_type) do
  # Фактури, ДИ, КИ - стандартна номерация
  DocumentNumbering.next_sales_invoice_number(tenant_id)
end
```

#### 3. CompanySettings схема

**Файл:** `apps/cyber_core/lib/cyber_core/settings/company_settings.ex`

**Полета:**

```elixir
schema "company_settings" do
  # ...

  # Номерация за продажби (фактури, ДИ, КИ) - 10 цифри с водеща нула
  field :sales_invoice_next_number, :integer, default: 1

  # Номерация за протоколи ВОП - 10 цифри с водеща нула
  field :vop_protocol_next_number, :integer, default: 1

  # ...
end
```

---

## Настройки

### UI за конфигурация

**URL:** http://localhost:4000/settings

**Секция:** "Номерация на документи"

#### Как да конфигурирате:

1. Отворете страницата за настройки
2. Намерете секцията "Номерация на документи"
3. Въведете началните стойности за:
   - **Следващ номер за фактури за продажба** (по подразбиране: 1)
   - **Следващ номер за протоколи ВОП** (по подразбиране: 1)
4. Кликнете "Запази настройките"

#### Превю на формата

UI показва как ще изглежда генерираният номер:
```
Текущ формат: 0000000001  ← Ако стойността е 1
Текущ формат: 0000001234  ← Ако стойността е 1234
```

#### Важни бележки

⚠️ **Внимание:** Промяната на начална стойност не променя вече издадени документи!

⚠️ **Внимание:** Не намалявайте стойността под последния издаден номер - това може да доведе до дублиращи се номера!

✅ **Препоръка:** Задавайте началните стойности само веднъж, при първоначална настройка на системата.

---

## API използване

### Създаване на фактура БЕЗ ръчен номер

```bash
POST /api/invoices
Content-Type: application/json

{
  "invoice": {
    "tenant_id": 1,
    "contact_id": 5,
    "issue_date": "2025-11-19",
    "billing_name": "Клиент ООД",
    "vat_document_type": "01"
    // invoice_no НЕ е зададено - ще се генерира автоматично
  },
  "lines": [...]
}
```

**Отговор:**

```json
{
  "data": {
    "id": 123,
    "invoice_no": "0000000001",  ← Автоматично генериран
    "vat_document_type": "01",
    "status": "draft",
    ...
  }
}
```

### Създаване на фактура С ръчен номер

```bash
POST /api/invoices
Content-Type: application/json

{
  "invoice": {
    "tenant_id": 1,
    "invoice_no": "CUSTOM-2025-001",  ← Ръчен номер
    "contact_id": 5,
    "vat_document_type": "01",
    ...
  }
}
```

**Резултат:** Системата ще използва `CUSTOM-2025-001` вместо да генерира автоматично.

### Проверка на текущия брояч

```elixir
iex> alias CyberCore.Settings.DocumentNumbering

iex> DocumentNumbering.current_counter(1, :sales_invoice_next_number)
{:ok, 42}

iex> DocumentNumbering.current_counter(1, :vop_protocol_next_number)
{:ok, 15}
```

---

## Примери

### Пример 1: Автоматична номерация на фактури

```elixir
# Първа фактура
{:ok, invoice1} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "01",  # Фактура
  contact_id: 10,
  issue_date: ~D[2025-11-19]
})
# invoice1.invoice_no => "0000000001"

# Втора фактура
{:ok, invoice2} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "01",
  contact_id: 11,
  issue_date: ~D[2025-11-19]
})
# invoice2.invoice_no => "0000000002"

# Дебитно известие (използва същата номерация)
{:ok, debit} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "02",  # Дебитно известие
  contact_id: 10,
  issue_date: ~D[2025-11-19]
})
# debit.invoice_no => "0000000003"
```

### Пример 2: Отделна номерация за протоколи ВОП

```elixir
# Протокол ВОП
{:ok, protocol1} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "09",  # Протокол
  contact_id: 12,
  issue_date: ~D[2025-11-19]
})
# protocol1.invoice_no => "0000000001"  ← Започва от 1, отделна номерация!

# Следваща фактура (продължава предишната номерация)
{:ok, invoice3} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "01",
  contact_id: 13,
  issue_date: ~D[2025-11-19]
})
# invoice3.invoice_no => "0000000004"  ← Продължава от примера по-горе

# Втори протокол ВОП
{:ok, protocol2} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "50",  # Протокол за горива
  contact_id: 14,
  issue_date: ~D[2025-11-19]
})
# protocol2.invoice_no => "0000000002"  ← Продължава протоколната номерация
```

### Пример 3: Ресетване на брояч (нова година)

```elixir
# В началото на нова календарна година
alias CyberCore.Settings.DocumentNumbering

# Ресетваме фактурите на 1
DocumentNumbering.reset_counter(1, :sales_invoice_next_number, 1)

# Ресетваме протоколите на 1
DocumentNumbering.reset_counter(1, :vop_protocol_next_number, 1)

# Първата фактура за новата година
{:ok, invoice} = Sales.create_invoice(%{
  tenant_id: 1,
  vat_document_type: "01",
  contact_id: 15,
  issue_date: ~D[2026-01-01]
})
# invoice.invoice_no => "0000000001"
```

---

## FAQ

### 1. Защо 10 цифри с водеща нула?

**Отговор:** Това е стандарт в български счетоводни системи и осигурява:
- Еднакъв формат за всички номера
- Лесно сортиране
- Съвместимост с НАП изисквания

### 2. Какво става ако изтрия фактура?

**Отговор:** Номерът **НЕ** се използва повторно. Броячът продължава напред. Например:
- Фактура 0000000001 ✓
- Фактура 0000000002 (изтрита) ✗
- Фактура 0000000003 ✓

### 3. Може ли да използвам собствен формат на номера?

**Отговор:** Да! При създаване на фактура, ако зададете `invoice_no`, системата няма да генерира автоматичен номер:

```elixir
Sales.create_invoice(%{
  invoice_no: "FAC-2025-001",  # Ръчен формат
  ...
})
```

### 4. Какво е "thread-safe" генериране?

**Отговор:** Системата използва database locks (`FOR UPDATE`), което гарантира че:
- Два потребителя НЕ могат да получат един и същ номер
- Няма race conditions
- Номерацията е последователна без пропуски при паралелни заявки

### 5. Как да променя началните стойности?

**Отговор:**
1. Чрез UI: Settings → Номерация на документи
2. Чрез код: `DocumentNumbering.reset_counter(tenant_id, field, new_value)`

⚠️ **Внимание:** Правете това само в началото, преди първи документ!

### 6. Как се обработват протоколи ВОП?

**Отговор:** Протоколите с кодове 09, 29, 50, 91-95 използват **отделна номерация** (`vop_protocol_next_number`), независима от фактурите.

### 7. Защо фактурите от доставчици нямат автоматична номерация?

**Отговор:** Фактурите от доставчици (`supplier_invoices`) използват номера на **доставчика** (полето `supplier_invoice_no`), а не наша номерация. Нашата вътрешна номерация (`invoice_no`) се задава ръчно или автоматично, но е само за вътрешна употреба.

### 8. Какво става при достигане на максимума (9999999999)?

**Отговор:** Системата позволява номера до 9,999,999,999. Ако достигнете този лимит, трябва да:
1. Ресетнете брояча
2. Или да преминете към нова серия с префикс

---

## Thread Safety и Concurrency

### Как работи механизмът

```elixir
defp next_number(tenant_id, field) do
  Repo.transaction(fn ->
    # 1. Заключваме записа
    settings =
      from(s in CompanySettings,
        where: s.tenant_id == ^tenant_id,
        lock: "FOR UPDATE"  ← Заключва реда в базата
      )
      |> Repo.one()

    # 2. Вземаме текущия номер
    current_number = Map.get(settings, field, 1)

    # 3. Форматираме номера
    formatted_number = generate_number(current_number)

    # 4. Увеличаваме брояча за следващия път
    updates = %{field => current_number + 1}
    Settings.update_company_settings(settings, updates)

    # 5. Връщаме форматирания номер
    formatted_number
  end)
end
```

### Сценарий с паралелни заявки

```
User A                    User B
------                    ------
Започва транзакция       |
Заключва реда            |
Чете: counter = 5        |
                         | Започва транзакция
                         | ЧАКА (редът е заключен)
Записва: counter = 6     |
Връща: "0000000005"      |
Приключва транзакция     |
                         | Заключва реда
                         | Чете: counter = 6
                         | Записва: counter = 7
                         | Връща: "0000000006"
                         | Приключва транзакция
```

**Резултат:** Няма дублиращи се номера! ✅

---

## Миграция и Rollback

### Миграция

**Файл:** `20251119194730_add_document_numbering_to_company_settings.exs`

```elixir
def change do
  alter table(:company_settings) do
    add :sales_invoice_next_number, :integer, default: 1
    add :vop_protocol_next_number, :integer, default: 1
  end
end
```

**Пускане:**
```bash
mix ecto.migrate
```

### Rollback (ако е необходимо)

```bash
mix ecto.rollback
```

---

## Тестване

### Unit тестове

```elixir
# test/cyber_core/settings/document_numbering_test.exs
defmodule CyberCore.Settings.DocumentNumberingTest do
  use CyberCore.DataCase
  alias CyberCore.Settings.DocumentNumbering

  test "generate_number/1 formats number with leading zeros" do
    assert DocumentNumbering.generate_number(1) == "0000000001"
    assert DocumentNumbering.generate_number(123) == "0000000123"
    assert DocumentNumbering.generate_number(9999999999) == "9999999999"
  end

  test "valid_number?/1 validates format" do
    assert DocumentNumbering.valid_number?("0000000001") == true
    assert DocumentNumbering.valid_number?("123") == false
    assert DocumentNumbering.valid_number?("abcd") == false
  end

  test "next_sales_invoice_number/1 generates sequential numbers" do
    tenant = insert(:tenant)
    insert(:company_settings, tenant_id: tenant.id, sales_invoice_next_number: 1)

    {:ok, number1} = DocumentNumbering.next_sales_invoice_number(tenant.id)
    {:ok, number2} = DocumentNumbering.next_sales_invoice_number(tenant.id)

    assert number1 == "0000000001"
    assert number2 == "0000000002"
  end
end
```

### Integration тестове

```elixir
# test/cyber_core/sales_test.exs
test "create_invoice/1 auto-generates invoice number" do
  tenant = insert(:tenant)
  insert(:company_settings, tenant_id: tenant.id)
  contact = insert(:contact, tenant_id: tenant.id)

  attrs = %{
    tenant_id: tenant.id,
    contact_id: contact.id,
    vat_document_type: "01",
    issue_date: ~D[2025-11-19]
  }

  {:ok, invoice} = Sales.create_invoice(attrs)

  assert invoice.invoice_no == "0000000001"
end
```

---

## Съвместимост с NAP файлове

### PRODAGBI.TXT формат

При генериране на NAP файлове, номерът се използва директно в полето "Номер на документ":

```
Позиции 59-76 (18 символа): Номер на документа
```

**Пример:**
```
0000000001        ← 10 цифри + 8 интервала = 18 символа (ляво изравнен)
```

### Забележка

ППЗДДС не изисква водещи нули в NAP файловете, но системата ги съхранява за вътрешна консистентност. При експорт може да се премахнат водещите нули, ако е необходимо.

---

## Поддръжка и Troubleshooting

### Проблем: "Следващият номер е по-малък от последния издаден"

**Причина:** Ръчно променен брояч или изтрита база данни

**Решение:**
```elixir
# Намерете последния издаден номер
last_invoice = Repo.one(
  from i in Invoice,
  where: i.tenant_id == ^tenant_id,
  order_by: [desc: i.id],
  limit: 1
)

# Парсирайте номера
{:ok, last_number} = DocumentNumbering.parse_number(last_invoice.invoice_no)

# Ресетнете брояча на следващия номер
DocumentNumbering.reset_counter(tenant_id, :sales_invoice_next_number, last_number + 1)
```

### Проблем: "Duplicate invoice_no constraint error"

**Причина:** Ръчно зададен номер, който вече съществува

**Решение:** Проверете дали номерът вече е използван преди да го зададете ръчно.

---

**Последна актуализация:** 19 ноември 2025
**Версия:** 1.0
**Автор:** Cyber ERP Team
