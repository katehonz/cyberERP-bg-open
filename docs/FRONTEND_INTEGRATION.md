# Frontend Интеграция - SAF-T за Дълготрайни Активи

## Промени в API

### Нови endpoints

#### 1. Увеличаване на стойността на актив
```
POST /api/accounting/assets/:id/increase-value
```

Използване от фронтенда:
```javascript
async function increaseAssetValue(assetId, amount, description) {
  const response = await fetch(`/api/accounting/assets/${assetId}/increase-value`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      amount: amount,
      transaction_date: new Date().toISOString().split('T')[0],
      description: description,
      regenerate_schedule: true
    })
  });

  return await response.json();
}
```

#### 2. Списък с транзакции
```
GET /api/accounting/assets/:id/transactions
```

```javascript
async function getAssetTransactions(assetId) {
  const response = await fetch(`/api/accounting/assets/${assetId}/transactions`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  return await response.json();
}
```

#### 3. Статистика за активи
```
GET /api/accounting/assets-statistics
```

```javascript
async function getAssetsStatistics() {
  const response = await fetch('/api/accounting/assets-statistics', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  return await response.json();
}
```

#### 4. Експорт на SAF-T файл
```
GET /api/accounting/assets-export-saft/:year
```

```javascript
function downloadSaftFile(year) {
  window.location.href = `/api/accounting/assets-export-saft/${year}`;
}
```

#### 5. Подготовка за нова година
```
POST /api/accounting/assets-prepare-year/:year
```

```javascript
async function prepareYearBeginning(year) {
  const response = await fetch(`/api/accounting/assets-prepare-year/${year}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  return await response.json();
}
```

---

## Разширени полета в Asset обект

Новите полета, които се връщат от API:

```javascript
{
  // Основни полета
  "id": 1,
  "code": "DMA-001",
  "name": "Лаптоп Dell",

  // Нови полета за SAF-T
  "startup_date": "2025-01-20",           // Дата на въвеждане в експлоатация
  "purchase_order_date": "2025-01-10",   // Дата на поръчка
  "inventory_number": "INV-2025-001",    // Инвентарен номер
  "serial_number": "SN123456",           // Сериен номер
  "location": "Офис София",              // Местонахождение
  "responsible_person": "Иван Иванов",   // МОЛ

  // SAF-T ValuationDAP полета
  "month_value_change": 3,                       // Месец на промяна на стойността
  "month_suspension_resumption": null,           // Месец на спиране/възобновяване
  "month_writeoff_accounting": null,             // Месец на отписване от счетоводен план
  "month_writeoff_tax": null,                    // Месец на отписване от данъчен план
  "depreciation_months_current_year": 10,        // Брой месеци амортизация през годината

  // SAF-T ValuationSAP полета
  "acquisition_cost_begin_year": "25000.00",     // Придобивна стойност - начало на година
  "book_value_begin_year": "25000.00",           // Балансова стойност - начало на година
  "accumulated_depreciation_begin_year": "0",    // Амортизация - начало на година

  // Допълнителни сметки
  "accumulated_depreciation_account_id": 15,     // Сметка за амортизация

  // При GET /api/accounting/assets/:id също се връщат:
  "accumulated_depreciation": "5000.00",         // Изчислена натрупана амортизация
  "book_value": "20000.00",                      // Изчислена балансова стойност
  "transactions": [...],                         // Масив с транзакции
  "supplier": {...}                              // Обект с данни за доставчик
}
```

---

## UI Компоненти за добавяне

### 1. Бутон "Увеличи стойността"

В детайлния изглед на актив добавете бутон:

```jsx
<button onClick={() => showIncreaseValueModal(asset.id)}>
  Увеличи стойността
</button>
```

Modal форма:
```jsx
<Modal title="Увеличаване на стойността на актив">
  <Form>
    <Input
      label="Сума на увеличението"
      type="number"
      name="amount"
      required
    />
    <DatePicker
      label="Дата"
      name="transaction_date"
      defaultValue={new Date()}
    />
    <TextArea
      label="Описание"
      name="description"
      placeholder="Подобрение - монтиране на ГБО"
    />
    <Checkbox
      label="Преизчисли амортизационния график"
      name="regenerate_schedule"
    />
    <Button type="submit">Запази</Button>
  </Form>
</Modal>
```

### 2. Таб "Транзакции"

В детайлния изглед добавете таб:

```jsx
<Tabs>
  <Tab label="Основни данни">...</Tab>
  <Tab label="Амортизационен график">...</Tab>
  <Tab label="Транзакции">
    <TransactionsTable transactions={asset.transactions} />
  </Tab>
</Tabs>
```

Таблица с транзакции:
```jsx
<Table>
  <thead>
    <tr>
      <th>Дата</th>
      <th>Тип</th>
      <th>Описание</th>
      <th>Сума</th>
      <th>Балансова стойност след</th>
    </tr>
  </thead>
  <tbody>
    {transactions.map(tx => (
      <tr key={tx.id}>
        <td>{formatDate(tx.transaction_date)}</td>
        <td>
          <Badge color={getTransactionColor(tx.transaction_type)}>
            {tx.transaction_type_name}
          </Badge>
        </td>
        <td>{tx.description}</td>
        <td>{formatCurrency(tx.transaction_amount)}</td>
        <td>{formatCurrency(tx.book_value_after)}</td>
      </tr>
    ))}
  </tbody>
</Table>
```

Helper функции:
```javascript
function getTransactionColor(type) {
  const colors = {
    '10': 'green',   // Придобиване
    '20': 'blue',    // Подобрение
    '30': 'gray',    // Амортизация
    '40': 'yellow',  // Преоценка
    '50': 'orange',  // Продажба
    '60': 'red',     // Брак
  };
  return colors[type] || 'gray';
}
```

### 3. Dashboard Widget - Статистика

```jsx
<Widget title="Дълготрайни Активи">
  <StatsList>
    <StatItem
      label="Общо активи"
      value={stats.total_count}
    />
    <StatItem
      label="Активни"
      value={stats.active_count}
      color="green"
    />
    <StatItem
      label="Обща стойност"
      value={formatCurrency(stats.total_acquisition_cost)}
    />
    <StatItem
      label="Балансова стойност"
      value={formatCurrency(stats.total_book_value)}
    />
  </StatsList>
</Widget>
```

### 4. Бутон "Експорт SAF-T"

В страницата с активи:

```jsx
<div className="toolbar">
  <Select
    label="Година"
    value={selectedYear}
    onChange={setSelectedYear}
  >
    <option value="2024">2024</option>
    <option value="2025">2025</option>
    <option value="2026">2026</option>
  </Select>

  <Button onClick={() => downloadSaftFile(selectedYear)}>
    <DownloadIcon />
    Изтегли SAF-T файл
  </Button>
</div>
```

### 5. Годишна процедура

В Settings или Admin панел:

```jsx
<Section title="Годишни процедури">
  <Card>
    <h3>Подготовка за нова година</h3>
    <p>
      Подготвя началните стойности на всички активи за SAF-T отчитане.
      Изпълнете тази операция на 1 януари.
    </p>
    <Select value={yearToPrepare} onChange={setYearToPrepare}>
      <option value="2025">2025</option>
      <option value="2026">2026</option>
    </Select>
    <Button
      variant="primary"
      onClick={handlePrepareYear}
    >
      Подготви година {yearToPrepare}
    </Button>
  </Card>
</Section>
```

---

## Валидации

### При създаване/редактиране на актив:

```javascript
const validationRules = {
  // Задължителни полета
  code: { required: true },
  name: { required: true },
  acquisition_date: { required: true },
  acquisition_cost: { required: true, min: 0 },
  useful_life_months: { required: true, min: 1 },

  // SAF-T специфични
  tax_category: {
    required: true,
    in: ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII']
  },
  startup_date: {
    afterOrEqual: 'acquisition_date'
  }
};
```

### При увеличаване на стойността:

```javascript
const increaseValueRules = {
  amount: {
    required: true,
    min: 0.01,
    numeric: true
  },
  transaction_date: {
    required: true,
    afterOrEqual: asset.acquisition_date
  }
};
```

---

## Примерен React компонент

```jsx
import React, { useState, useEffect } from 'react';

function AssetDetails({ assetId }) {
  const [asset, setAsset] = useState(null);
  const [showIncreaseModal, setShowIncreaseModal] = useState(false);

  useEffect(() => {
    fetchAsset();
  }, [assetId]);

  async function fetchAsset() {
    const response = await fetch(`/api/accounting/assets/${assetId}`);
    const data = await response.json();
    setAsset(data.data);
  }

  async function handleIncreaseValue(formData) {
    const response = await fetch(
      `/api/accounting/assets/${assetId}/increase-value`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      }
    );

    if (response.ok) {
      const result = await response.json();
      alert(result.data.message);
      fetchAsset(); // Refresh asset data
      setShowIncreaseModal(false);
    }
  }

  if (!asset) return <div>Loading...</div>;

  return (
    <div>
      <h1>{asset.name}</h1>

      <div className="asset-info">
        <InfoRow label="Код" value={asset.code} />
        <InfoRow label="Придобивна стойност"
                 value={formatCurrency(asset.acquisition_cost)} />
        <InfoRow label="Балансова стойност"
                 value={formatCurrency(asset.book_value)} />
        <InfoRow label="Месец на промяна"
                 value={asset.month_value_change || 'Няма'} />
      </div>

      <button onClick={() => setShowIncreaseModal(true)}>
        Увеличи стойността
      </button>

      <Tabs>
        <Tab label="Амортизация">
          <DepreciationSchedule schedule={asset.depreciation_schedule} />
        </Tab>
        <Tab label="Транзакции">
          <TransactionsList transactions={asset.transactions} />
        </Tab>
      </Tabs>

      {showIncreaseModal && (
        <IncreaseValueModal
          onSubmit={handleIncreaseValue}
          onClose={() => setShowIncreaseModal(false)}
        />
      )}
    </div>
  );
}
```

---

## Тестване

```bash
# 1. Тест на статистика
curl http://localhost:4000/api/accounting/assets-statistics

# 2. Тест на увеличаване на стойност
curl -X POST http://localhost:4000/api/accounting/assets/1/increase-value \
  -H "Content-Type: application/json" \
  -d '{
    "amount": "5000.00",
    "description": "Тестово подобрение"
  }'

# 3. Тест на транзакции
curl http://localhost:4000/api/accounting/assets/1/transactions

# 4. Тест на SAF-T експорт
curl http://localhost:4000/api/accounting/assets-export-saft/2025 \
  -o saft_test.xml
```

---

## Важни бележки

1. **Authentication** - Всички endpoints изискват валиден Bearer token
2. **Tenant isolation** - Данните автоматично се филтрират по текущия tenant
3. **Decimal precision** - Всички суми са Decimal с 2 знака след десетичната запетая
4. **Date format** - ISO 8601 (YYYY-MM-DD)
5. **Error handling** - Винаги проверявайте response.ok преди да parse-вате JSON

---

Вижте пълната API документация в `docs/API_FIXED_ASSETS.md`
