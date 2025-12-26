# API Документация за Дълготрайни Активи (ДМА)

## Общи endpoints

### GET /api/accounting/assets
Връща списък с всички активи за текущия tenant.

**Query параметри:**
- `status` - Филтър по статус (active, disposed, fully_depreciated)
- `category` - Филтър по категория

**Отговор:**
```json
{
  "data": [
    {
      "id": 1,
      "code": "DMA-001",
      "name": "Лаптоп Dell Latitude",
      "category": "Компютърна техника",
      "acquisition_date": "2025-01-15",
      "acquisition_cost": "2400.00",
      "status": "active",
      ...
    }
  ]
}
```

### GET /api/accounting/assets/:id
Връща подробна информация за актив, включително амортизационен график и транзакции.

**Отговор:**
```json
{
  "data": {
    "id": 1,
    "code": "DMA-001",
    "name": "Лаптоп Dell Latitude",
    "acquisition_cost": "2400.00",
    "accumulated_depreciation": "0",
    "book_value": "2400.00",
    "tax_category": "IV",
    "startup_date": "2025-01-20",
    "purchase_order_date": "2025-01-10",
    "month_value_change": null,
    "depreciation_schedule": [...],
    "transactions": [...],
    "supplier": {...}
  }
}
```

### POST /api/accounting/assets
Създава нов актив.

**Request body:**
```json
{
  "asset": {
    "code": "DMA-002",
    "name": "Автомобил VW Golf",
    "category": "Транспортни средства",
    "tax_category": "V",
    "acquisition_date": "2025-02-01",
    "acquisition_cost": "25000.00",
    "startup_date": "2025-02-05",
    "useful_life_months": 48,
    "depreciation_method": "straight_line",
    "supplier_id": 5,
    "invoice_number": "INV-2025-001"
  }
}
```

### PUT /api/accounting/assets/:id
Актуализира съществуващ актив.

### DELETE /api/accounting/assets/:id
Изтрива актив.

---

## Нови SAF-T специфични endpoints

### POST /api/accounting/assets/:id/increase-value
Увеличава стойността на актив (подобрение).

**Request body:**
```json
{
  "amount": "5000.00",
  "transaction_date": "2025-03-15",
  "description": "Подобрение - монтиране на ГБО",
  "regenerate_schedule": true
}
```

**Отговор:**
```json
{
  "data": {
    "asset": {
      "id": 1,
      "acquisition_cost": "30000.00",
      "month_value_change": 3,
      ...
    },
    "transaction": {
      "id": 15,
      "transaction_type": "20",
      "transaction_type_name": "IMP - Подобрение/Увеличаване",
      "transaction_amount": "5000.00",
      "transaction_date": "2025-03-15",
      ...
    },
    "message": "Стойността на актива е успешно увеличена"
  }
}
```

**Параметри:**
- `amount` (задължително) - Сумата на увеличението
- `transaction_date` (опционално) - Дата на транзакцията (по подразбиране днес)
- `description` (опционално) - Описание на подобрението
- `regenerate_schedule` (опционално, boolean) - Дали да преизчисли амортизационния график

**Какво прави:**
1. Увеличава `acquisition_cost` на актива
2. Записва `month_value_change` за SAF-T
3. Създава транзакция тип "20" (IMP)
4. Опционално преизчислява амортизационния график

---

### GET /api/accounting/assets/:id/transactions
Връща списък с всички транзакции за даден актив.

**Отговор:**
```json
{
  "data": [
    {
      "id": 1,
      "transaction_type": "10",
      "transaction_type_name": "ACQ - Придобиване",
      "transaction_date": "2025-01-15",
      "description": "Придобиване на актив",
      "transaction_amount": "25000.00",
      "acquisition_cost_change": "25000.00",
      "book_value_after": "25000.00",
      "year": 2025,
      "month": 1
    },
    {
      "id": 2,
      "transaction_type": "20",
      "transaction_type_name": "IMP - Подобрение/Увеличаване",
      "transaction_date": "2025-03-15",
      "transaction_amount": "5000.00",
      "acquisition_cost_change": "5000.00",
      "book_value_after": "28500.00",
      "year": 2025,
      "month": 3
    },
    {
      "id": 3,
      "transaction_type": "30",
      "transaction_type_name": "DEP - Амортизация",
      "transaction_date": "2025-01-31",
      "transaction_amount": "500.00",
      "book_value_after": "24500.00",
      "year": 2025,
      "month": 1
    }
  ]
}
```

**Типове транзакции:**
- `10` - ACQ (Acquisition) - Придобиване
- `20` - IMP (Improvement) - Подобрение/Увеличаване
- `30` - DEP (Depreciation) - Амортизация
- `40` - REV (Revaluation) - Преоценка
- `50` - DSP (Disposal) - Продажба
- `60` - SCR (Scrap) - Брак/Отписване
- `70` - TRF (Transfer) - Вътрешен трансфер
- `80` - COR (Correction) - Корекция

---

### GET /api/accounting/assets-statistics
Връща обща статистика за активите.

**Отговор:**
```json
{
  "data": {
    "total_count": 15,
    "active_count": 12,
    "disposed_count": 3,
    "total_acquisition_cost": "145000.00",
    "total_accumulated_depreciation": "28500.00",
    "total_book_value": "116500.00"
  }
}
```

---

### GET /api/accounting/assets-export-saft/:year
Генерира и изтегля SAF-T годишен XML файл за дадена година.

**URL параметри:**
- `year` - Година (напр. 2025)

**Отговор:**
- Content-Type: `application/xml`
- Content-Disposition: `attachment; filename="saft_annual_2025.xml"`
- XML файл съдържащ:
  - MasterFilesAnnual/Assets - Списък с активи с ValuationSAP и ValuationDAP
  - SourceDocumentsAnnual/AssetTransactions - Всички транзакции

**Пример:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:4000/api/accounting/assets-export-saft/2025 \
  -o saft_annual_2025.xml
```

---

### POST /api/accounting/assets-prepare-year/:year
Подготвя началните стойности за всички активи в началото на годината.

**URL параметри:**
- `year` - Година (напр. 2025)

**Отговор:**
```json
{
  "data": {
    "message": "Успешно подготвени началните стойности за 15 активa",
    "year": 2025,
    "assets_count": 15
  }
}
```

**Какво прави:**
За всеки актив записва:
- `acquisition_cost_begin_year` - Придобивна стойност в началото на годината
- `book_value_begin_year` - Балансова стойност в началото на годината
- `accumulated_depreciation_begin_year` - Натрупана амортизация в началото на годината
- `depreciation_months_current_year` - Нулира броя месеци с амортизация

**ВАЖНО:** Тази операция трябва да се извършва на 1 януари всяка година!

---

## Работен процес

### 1. Създаване на нов актив
```bash
POST /api/accounting/assets
{
  "asset": {
    "code": "DMA-100",
    "name": "Автомобил VW Golf",
    "tax_category": "V",
    "acquisition_date": "2025-01-15",
    "acquisition_cost": "25000.00",
    "startup_date": "2025-01-20",
    "useful_life_months": 48,
    "depreciation_method": "straight_line"
  }
}
```

### 2. Увеличаване на стойността (през март)
```bash
POST /api/accounting/assets/100/increase-value
{
  "amount": "3000.00",
  "transaction_date": "2025-03-10",
  "description": "Подобрение - ГБО система",
  "regenerate_schedule": true
}
```

### 3. Проверка на транзакциите
```bash
GET /api/accounting/assets/100/transactions
```

### 4. Генериране на SAF-T файл (края на годината)
```bash
GET /api/accounting/assets-export-saft/2025
```

---

## Типични грешки

### 400 Bad Request
```json
{
  "error": "Невалидна година"
}
```

### 404 Not Found
Актив не е намерен.

### 422 Unprocessable Entity
```json
{
  "error": "Грешка при генериране на SAF-T файл: ..."
}
```

---

## Примери за използване

### JavaScript/Fetch
```javascript
// Увеличаване на стойността на актив
const response = await fetch('/api/accounting/assets/1/increase-value', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_TOKEN'
  },
  body: JSON.stringify({
    amount: "5000.00",
    transaction_date: "2025-03-15",
    description: "Подобрение на активa",
    regenerate_schedule: true
  })
});

const result = await response.json();
console.log(result.data.message); // "Стойността на актива е успешно увеличена"
```

### cURL
```bash
# Статистика за активи
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:4000/api/accounting/assets-statistics

# Подготовка за нова година
curl -X POST -H "Authorization: Bearer TOKEN" \
  http://localhost:4000/api/accounting/assets-prepare-year/2026

# Изтегляне на SAF-T файл
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:4000/api/accounting/assets-export-saft/2025 \
  -o saft_2025.xml
```

---

## Автоматични транзакции

Системата автоматично записва транзакции при:

1. **Постване на амортизация** - Създава транзакция тип "30" (DEP)
2. **Извеждане от употреба** - Създава транзакция тип "50" (DSP) или "60" (SCR)

За **придобиване** трябва ръчно да се извика:
```elixir
FixedAssets.record_acquisition_transaction(asset)
```

---

## Бележки

- Всички суми са в лева (BGN) като Decimal
- Датите са в ISO 8601 формат (YYYY-MM-DD)
- Транзакциите се записват автоматично при повечето операции
- SAF-T файлът се генерира според BG Schema V 1.0.1
- За правилно SAF-T отчитане задължително изпълнете `prepare_year_beginning` в началото на всяка година
