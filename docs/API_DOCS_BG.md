# API Документация - Cyber ERP

## 📋 Съдържание

1. [Обща информация](#обща-информация)
2. [Аутентикация](#аутентикация)
3. [Inventory Module](#inventory-module)
4. [Sales Module](#sales-module)
5. [Purchase Module](#purchase-module)
6. [Bank Module](#bank-module)
7. [Общи отговори](#общи-отговори)

---

## 🔧 Обща информация

### Base URL
```
http://localhost:4000/api
```

### Headers
Всички заявки към API трябва да включват следните headers:
```http
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN_HERE
X-Tenant-ID: YOUR_TENANT_ID
```

### Multi-tenancy
Системата използва row-level multi-tenancy. Всеки request автоматично се филтрира по `tenant_id` от текущия автентикиран потребител.

---

## 🔐 Аутентикация

### Регистрация
```http
POST /api/auth/register
```

**Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "name": "Потребителско име"
}
```

### Вход
```http
POST /api/auth/login
```

**Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Потребителско име"
  }
}
```

### Текущ потребител
```http
GET /api/auth/me
```

---

## 📦 Inventory Module

### Складове (Warehouses)

#### Списък складове
```http
GET /api/warehouses
GET /api/warehouses?is_active=true
```

#### Детайли за склад
```http
GET /api/warehouses/:id
```

#### Създаване на склад
```http
POST /api/warehouses
```

**Body:**
```json
{
  "warehouse": {
    "code": "WH001",
    "name": "Главен склад",
    "address": "София, бул. Витоша 1",
    "city": "София",
    "postal_code": "1000",
    "country": "BG",
    "is_active": true,
    "notes": "Основен склад на фирмата"
  }
}
```

#### Актуализиране на склад
```http
PUT /api/warehouses/:id
```

#### Изтриване на склад
```http
DELETE /api/warehouses/:id
```

---

## 💰 Sales Module

### Фактури (Invoices)

#### Списък фактури
```http
GET /api/invoices
GET /api/invoices?status=issued
GET /api/invoices?contact_id=1
GET /api/invoices?from=2025-01-01&to=2025-12-31
GET /api/invoices?search=INV-2025
```

**Филтри:**
- `status`: draft, issued, paid, partially_paid, overdue, cancelled
- `invoice_type`: standard, credit_note, debit_note, proforma
- `contact_id`: ID на клиент
- `from`: От дата (YYYY-MM-DD)
- `to`: До дата (YYYY-MM-DD)
- `search`: Търсене в номер, клиент

#### Детайли за фактура
```http
GET /api/invoices/:id
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "tenant_id": 1,
    "contact_id": 1,
    "invoice_no": "INV-2025-001",
    "invoice_type": "standard",
    "status": "issued",
    "issue_date": "2025-10-11",
    "due_date": "2025-11-11",
    "billing_name": "Клиент ООД",
    "billing_address": "София, ул. Примерна 1",
    "billing_vat_number": "BG123456789",
    "subtotal": "1000.00",
    "tax_amount": "200.00",
    "total_amount": "1200.00",
    "paid_amount": "0.00",
    "currency": "BGN",
    "invoice_lines": [
      {
        "id": 1,
        "product_id": 1,
        "description": "Продукт 1",
        "quantity": "10.00",
        "unit_price": "100.00",
        "discount_percent": "0.00",
        "tax_rate": "20.00",
        "subtotal": "1000.00",
        "tax_amount": "200.00",
        "total_amount": "1200.00"
      }
    ]
  }
}
```

#### Създаване на фактура с редове
```http
POST /api/invoices
```

**Body:**
```json
{
  "invoice": {
    "contact_id": 1,
    "invoice_no": "INV-2025-002",
    "issue_date": "2025-10-11",
    "due_date": "2025-11-11",
    "billing_name": "Клиент ООД",
    "billing_address": "София, ул. Примерна 1",
    "billing_vat_number": "BG123456789"
  },
  "lines": [
    {
      "product_id": 1,
      "description": "Продукт 1",
      "quantity": "10.00",
      "unit_price": "50.00",
      "discount_percent": "10.00",
      "tax_rate": "20.00"
    },
    {
      "product_id": 2,
      "description": "Продукт 2",
      "quantity": "5.00",
      "unit_price": "100.00",
      "tax_rate": "20.00"
    }
  ]
}
```

**Забележка:** Полетата `subtotal`, `tax_amount`, `total_amount` се изчисляват автоматично!

#### Актуализиране на фактура
```http
PUT /api/invoices/:id
```

#### Изтриване на фактура
```http
DELETE /api/invoices/:id
```

---

### Оферти (Quotations)

#### Списък оферти
```http
GET /api/quotations
GET /api/quotations?status=sent
GET /api/quotations?contact_id=1
```

**Филтри:**
- `status`: draft, sent, accepted, rejected, expired
- `contact_id`: ID на клиент
- `from`: От дата
- `to`: До дата
- `search`: Търсене

#### Детайли за оферта
```http
GET /api/quotations/:id
```

#### Създаване на оферта с редове
```http
POST /api/quotations
```

**Body:**
```json
{
  "quotation": {
    "contact_id": 1,
    "quotation_no": "QUO-2025-001",
    "issue_date": "2025-10-11",
    "valid_until": "2025-11-11",
    "contact_name": "Клиент ООД",
    "contact_email": "client@example.com",
    "contact_phone": "+359888123456"
  },
  "lines": [
    {
      "product_id": 1,
      "description": "Продукт 1",
      "quantity": "10.00",
      "unit_price": "50.00",
      "tax_rate": "20.00"
    }
  ]
}
```

#### Конвертиране на оферта във фактура
```http
POST /api/quotations/:id/convert
```

**Response:**
```json
{
  "message": "Офертата беше успешно конвертирана във фактура",
  "invoice_id": 5,
  "invoice_no": "INV-2025-005"
}
```

---

## 🛒 Purchase Module

### Поръчки за покупка (Purchase Orders)

#### Списък поръчки
```http
GET /api/purchase_orders
GET /api/purchase_orders?status=pending
GET /api/purchase_orders?supplier_id=1
```

**Филтри:**
- `status`: draft, sent, confirmed, receiving, received, cancelled
- `supplier_id`: ID на доставчик
- `from`: От дата
- `to`: До дата
- `search`: Търсене

#### Създаване на поръчка с редове
```http
POST /api/purchase_orders
```

**Body:**
```json
{
  "purchase_order": {
    "supplier_id": 1,
    "order_no": "PO-2025-001",
    "order_date": "2025-10-11",
    "expected_date": "2025-10-25",
    "supplier_name": "Доставчик ООД",
    "supplier_address": "София, ул. Доставчик 1",
    "supplier_vat_number": "BG987654321"
  },
  "lines": [
    {
      "product_id": 1,
      "description": "Суровина 1",
      "quantity_ordered": "100.00",
      "unit_price": "30.00",
      "tax_rate": "20.00"
    }
  ]
}
```

---

## 🏦 Bank Module

### Банкови сметки (Bank Accounts)

#### Списък банкови сметки
```http
GET /api/bank_accounts
GET /api/bank_accounts?is_active=true
GET /api/bank_accounts?currency=BGN
```

#### Създаване на банкова сметка
```http
POST /api/bank_accounts
```

**Body:**
```json
{
  "bank_account": {
    "account_no": "1234567890",
    "iban": "BG80BNBG96611020345678",
    "bic": "UNCRBGSF",
    "bank_name": "Уникредит Булбанк",
    "currency": "BGN",
    "initial_balance": "10000.00",
    "current_balance": "10000.00"
  }
}
```

**ВАЖНО:** Полето `current_balance` НЕ трябва да се актуализира директно! Използвайте банкови транзакции.

---

### Банкови транзакции (Bank Transactions)

#### Списък транзакции
```http
GET /api/bank_transactions
GET /api/bank_transactions?bank_account_id=1
GET /api/bank_transactions?transaction_type=receipt
GET /api/bank_transactions?is_reconciled=false
```

**Филтри:**
- `bank_account_id`: ID на банкова сметка
- `transaction_type`: payment, receipt, transfer, fee, interest, adjustment
- `status`: draft, pending, completed, reconciled, cancelled
- `is_reconciled`: true/false
- `from`: От дата
- `to`: До дата
- `search`: Търсене

#### Създаване на транзакция
```http
POST /api/bank_transactions
```

**Body:**
```json
{
  "bank_transaction": {
    "bank_account_id": 1,
    "transaction_type": "receipt",
    "transaction_date": "2025-10-11",
    "amount": "500.00",
    "currency": "BGN",
    "counterparty_name": "Клиент ООД",
    "counterparty_iban": "BG12UNCR12345678901234",
    "description": "Плащане по фактура INV-2025-001",
    "status": "completed"
  }
}
```

**ВАЖНО:** Създаването на транзакция автоматично актуализира баланса на банковата сметка!

**Типове транзакции:**
- `payment` - изходящо плащане (намалява баланса)
- `receipt` - постъпление (увеличава баланса)
- `transfer` - трансфер (зависи от посоката)
- `fee` - такса (намалява баланса)
- `interest` - лихва (увеличава баланса)
- `adjustment` - корекция

#### Маркиране на транзакция като изравнена
```http
POST /api/bank_transactions/:id/reconcile
```

---

## 📄 Общи отговори

### Успешен отговор
```json
{
  "data": { ... }
}
```

### Списък
```json
{
  "data": [ ... ]
}
```

### Грешка при валидация
```json
{
  "errors": {
    "invoice_no": ["has already been taken"],
    "contact_id": ["can't be blank"]
  }
}
```

### Not Found
```json
{
  "error": "resource not found"
}
```

### Unauthorized
```json
{
  "error": "unauthorized"
}
```

---

## 🎯 Забележки

1. **Автоматични изчисления:** Всички финансови полета (`subtotal`, `tax_amount`, `total_amount`) се изчисляват автоматично при създаване/актуализиране на редове.

2. **Multi-tenancy:** Всички заявки автоматично се филтрират по `tenant_id` от текущия потребител.

3. **Валидации:** API връща детайлни съобщения за грешки при невалидни данни.

4. **Dates:** Всички дати са във формат `YYYY-MM-DD`.

5. **Decimals:** Всички цени и количества са decimal полета с висока точност.

6. **Transaction safety:** Операции като създаване на фактура с редове или банкови транзакции използват database transactions за целостност.

---

## 📞 Поддръжка

За въпроси и проблеми:
- GitHub Issues: https://github.com/your-repo/cyber_erp/issues
- Email: support@cyberерп.bg
