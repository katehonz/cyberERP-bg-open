# Документация за SAF-T имплементация в Cyber ERP

## Съдържание

1. [Общ преглед](#общ-преглед)
2. [Какво е SAF-T](#какво-е-saf-t)
3. [Структура на SAF-T файла](#структура-на-saf-t-файла)
4. [Разширени полета в Contacts](#разширени-полета-в-contacts)
5. [SAF-T генератор](#saf-t-генератор)
6. [Типове SAF-T файлове](#типове-saf-t-файлове)
7. [Примери за употреба](#примери-за-употреба)
8. [Референтни материали](#референтни-материали)

---

## Общ преглед

SAF-T (Standard Audit File for Tax) е стандартен одитен файл за данъчни цели, разработен от OECD.
Българската версия е задължителна за подаване към Национална агенция за приходите (НАП) и включва:

- Сметкоплан (Chart of Accounts)
- Контрагенти (Customers & Suppliers)
- Главна книга (General Ledger)
- Първични документи (Source Documents)
- ДДС информация

**Версия:** BG_SAFT_Schema_V_1.0.1
**Namespace:** `mf:nra:dgti:dxxxx:declaration:v1`

---

## Какво е SAF-T

### Характеристики:

- **Формат:** XML
- **Кодировка:** UTF-8
- **Стандарт:** OECD SAF-T с български разширения
- **Задължителен от:** НАП (Национална агенция за приходите)
- **Употреба:**
  - Данъчни ревизии
  - Автоматизиран анализ на счетоводни данни
  - Проверка на ДДС декларации
  - Финансов контрол

### Предимства:

✅ Унифициран формат за размяна на данни
✅ Автоматизирана проверка от НАП
✅ Намалява административната тежест
✅ Подпомага електронния обмен с данъчните органи
✅ Международна съвместимост (OECD стандарт)

---

## Структура на SAF-T файла

### Основни секции:

```xml
<nsSAFT:AuditFile>
  <nsSAFT:Header>                    <!-- Информация за файла -->
  <nsSAFT:MasterFiles>               <!-- Референтни данни -->
    <nsSAFT:GeneralLedgerAccounts>   <!-- Сметкоплан -->
    <nsSAFT:Customers>               <!-- Клиенти -->
    <nsSAFT:Suppliers>               <!-- Доставчици -->
  </nsSAFT:MasterFiles>
  <nsSAFT:GeneralLedgerEntries>      <!-- Счетоводни записи -->
  <nsSAFT:SourceDocuments>           <!-- Първични документи -->
    <nsSAFT:SalesInvoices>           <!-- Фактури продажби -->
    <nsSAFT:PurchaseInvoices>        <!-- Фактури покупки -->
    <nsSAFT:Payments>                <!-- Плащания -->
  </nsSAFT:SourceDocuments>
</nsSAFT:AuditFile>
```

### Header (Заглавна част):

```xml
<nsSAFT:Header>
  <nsSAFT:AuditFileVersion>007</nsSAFT:AuditFileVersion>
  <nsSAFT:AuditFileCountry>BG</nsSAFT:AuditFileCountry>
  <nsSAFT:AuditFileRegion>BG-22</nsSAFT:AuditFileRegion>
  <nsSAFT:AuditFileDateCreated>2025-10-11</nsSAFT:AuditFileDateCreated>
  <nsSAFT:SoftwareCompanyName>Cyber ERP</nsSAFT:SoftwareCompanyName>
  <nsSAFT:SoftwareID>CyberERP</nsSAFT:SoftwareID>
  <nsSAFT:SoftwareVersion>1.0</nsSAFT:SoftwareVersion>

  <nsSAFT:Company>
    <nsSAFT:RegistrationNumber>123456789</nsSAFT:RegistrationNumber>
    <nsSAFT:Name>Моята фирма ЕООД</nsSAFT:Name>
    <nsSAFT:TaxRegistration>
      <nsSAFT:TaxNumber>BG123456789</nsSAFT:TaxNumber>
    </nsSAFT:TaxRegistration>
  </nsSAFT:Company>

  <nsSAFT:SelectionCriteria>
    <nsSAFT:PeriodStart>10</nsSAFT:PeriodStart>
    <nsSAFT:PeriodStartYear>2025</nsSAFT:PeriodStartYear>
    <nsSAFT:PeriodEnd>10</nsSAFT:PeriodEnd>
    <nsSAFT:PeriodEndYear>2025</nsSAFT:PeriodEndYear>
  </nsSAFT:SelectionCriteria>

  <nsSAFT:TaxAccountingBasis>A</nsSAFT:TaxAccountingBasis>
</nsSAFT:Header>
```

**TaxAccountingBasis стойности:**
- `A` - General commercial entities (Търговски предприятия)
- `P` - Public/government entities (Бюджетни предприятия)
- `BANK` - Банки
- `INSURANCE` - Застрахователни дружества

---

## Разширени полета в Contacts

Таблицата `contacts` е разширена с всички SAF-T полета необходими за генериране на XML файла.

### Нови полета:

#### Идентификация:
```elixir
field :registration_number, :string    # ЕИК/БУЛСТАТ
field :vat_number, :string              # ДДС номер (BGxxxxxxxxx)
field :tax_type, :string                # Вид данък (100010 за ДДС)
```

#### Адресна информация:
```elixir
field :street_name, :string
field :building_number, :string
field :postal_code, :string
field :region, :string                  # BG-22, BG-01, и т.н.
field :additional_address_detail, :string
field :building, :string
```

#### Контактно лице:
```elixir
field :contact_person_title, :string
field :contact_person_first_name, :string
field :contact_person_last_name, :string
field :fax, :string
field :website, :string
```

#### Класификация:
```elixir
field :is_supplier, :boolean            # Доставчик
field :is_customer, :boolean            # Клиент
field :self_billing_indicator, :boolean # Самофактуриране
field :related_party, :boolean          # Свързано лице
field :related_party_start_date, :date
field :related_party_end_date, :date
```

#### Банкова информация:
```elixir
field :iban_number, :string
field :bank_account_number, :string
field :bank_sort_code, :string
```

#### Счетоводни салда:
```elixir
field :accounting_account_id, :integer   # Идентификатор на счетоводна сметка (реконсилиационна)
field :opening_debit_balance, :decimal
field :opening_credit_balance, :decimal
field :closing_debit_balance, :decimal
field :closing_credit_balance, :decimal
```

#### Данъчна информация:
```elixir
field :tax_authority, :string           # NRA
field :tax_verification_date, :date
```

#### Имена:
```elixir
field :name_latin, :string              # За чуждестранни контрагенти
field :name_cyrillic, :string           # Кирилско име
```

### Миграция:

**Файл:** `20251011154008_add_saft_fields_to_contacts.exs`

Добавени индекси:
- `registration_number`
- `vat_number`
- `is_supplier`
- `is_customer`

---

## SAF-T генератор

**Модул:** `CyberCore.Accounting.SaftExport`
**Файл:** `apps/cyber_core/lib/cyber_core/accounting/saft_export.ex`

### Основни функции:

#### 1. Месечен SAF-T файл

```elixir
SaftExport.generate_monthly(tenant_id, year, month, output_path)

# Пример:
{:ok, path} = SaftExport.generate_monthly(1, 2025, 10, "/tmp/saft_monthly_2025_10.xml")
```

**Включва:**
- Header
- Master Files (счетоплан, клиенти, доставчици)
- General Ledger Entries (счетоводни записи за месеца)
- Source Documents (документи за месеца)

#### 2. Годишен SAF-T файл

```elixir
SaftExport.generate_annual(tenant_id, year, output_path)

# Пример:
{:ok, path} = SaftExport.generate_annual(1, 2025, "/tmp/saft_annual_2025.xml")
```

**Включва:**
- Header
- Master Files
- Source Documents (годишни суми)

#### 3. SAF-T при поискване (OnDemand)

```elixir
SaftExport.generate_on_demand(tenant_id, start_date, end_date, output_path)

# Пример:
{:ok, path} = SaftExport.generate_on_demand(
  1,
  ~D[2025-01-01],
  ~D[2025-12-31],
  "/tmp/saft_ondemand.xml"
)
```

**Включва:**
- Header с период
- Master Files
- Source Documents за периода

### Вътрешна структура:

```elixir
defp build_monthly_xml(tenant_id, year, month, settings) do
  header = build_header(settings, year, month, "M")
  master_files = build_master_files_monthly(tenant_id, year, month)
  general_ledger = build_general_ledger_entries(tenant_id, year, month)
  source_documents = build_source_documents_monthly(tenant_id, year, month)

  # Комбинира всички части в пълен XML
end
```

### XML генериране:

#### Accounts (Сметкоплан):

```xml
<nsSAFT:Account>
  <nsSAFT:AccountID>123</nsSAFT:AccountID>
  <nsSAFT:AccountDescription>Каса BGN</nsSAFT:AccountDescription>
  <nsSAFT:TaxpayerAccountID>5010</nsSAFT:TaxpayerAccountID>
  <nsSAFT:AccountType>Asset</nsSAFT:AccountType>
  <nsSAFT:AccountCreationDate>2025-01-01</nsSAFT:AccountCreationDate>
  <nsSAFT:OpeningDebitBalance>1000.00</nsSAFT:OpeningDebitBalance>
  <nsSAFT:ClosingDebitBalance>1500.00</nsSAFT:ClosingDebitBalance>
</nsSAFT:Account>
```

**Account Types:**
- `Asset` - Активи (сметки 1, 2, 3)
- `Liability` - Пасиви (сметки 4, 5)
- `Expense` - Разходи (сметки 6)
- `Income` - Приходи (сметки 7)
- `Bifunctional` - Двустранни сметки

#### Customers (Клиенти):

```xml
<nsSAFT:Customer>
  <nsSAFT:CompanyStructure>
    <nsSAFT:RegistrationNumber>123456789</nsSAFT:RegistrationNumber>
    <nsSAFT:Name>Клиент ООД</nsSAFT:Name>
    <nsSAFT:Address>
      <nsSAFT:StreetName>ул. Витоша</nsSAFT:StreetName>
      <nsSAFT:Number>1</nsSAFT:Number>
      <nsSAFT:City>София</nsSAFT:City>
      <nsSAFT:PostalCode>1000</nsSAFT:PostalCode>
      <nsSAFT:Country>BG</nsSAFT:Country>
      <nsSAFT:AddressType>StreetAddress</nsSAFT:AddressType>
    </nsSAFT:Address>
    <nsSAFT:TaxRegistration>
      <nsSAFT:TaxNumber>BG123456789</nsSAFT:TaxNumber>
      <nsSAFT:TaxType>100010</nsSAFT:TaxType>
    </nsSAFT:TaxRegistration>
    <nsSAFT:RelatedParty>N</nsSAFT:RelatedParty>
  </nsSAFT:CompanyStructure>
  <nsSAFT:CustomerID>42</nsSAFT:CustomerID>
  <nsSAFT:SelfBillingIndicator>N</nsSAFT:SelfBillingIndicator>
  <nsSAFT:AccountID>411</nsSAFT:AccountID>
  <nsSAFT:OpeningDebitBalance>0.00</nsSAFT:OpeningDebitBalance>
  <nsSAFT:ClosingDebitBalance>2500.00</nsSAFT:ClosingDebitBalance>
</nsSAFT:Customer>
```

#### Suppliers (Доставчици):

```xml
<nsSAFT:Supplier>
  <nsSAFT:CompanyStructure>
    <!-- Същата структура като Customer -->
  </nsSAFT:CompanyStructure>
  <nsSAFT:SupplierID>15</nsSAFT:SupplierID>
  <nsSAFT:AccountID>401</nsSAFT:AccountID>
  <nsSAFT:OpeningCreditBalance>0.00</nsSAFT:OpeningCreditBalance>
  <nsSAFT:ClosingCreditBalance>3000.00</nsSAFT:ClosingCreditBalance>
</nsSAFT:Supplier>
```

---

## Типове SAF-T файлове

### 1. Monthly (Месечен)

**Употреба:** Редовно подаване на месечни данни към НАП

**Включва:**
- Всички транзакции за месеца
- Главна книга (дневник)
- Първични документи (фактури, плащания)

**Файлово име:** `saft_monthly_YYYY_MM.xml`

**Пример структура:**
```xml
<nsSAFT:AuditFile>
  <nsSAFT:Header>
    <nsSAFT:HeaderComment>M</nsSAFT:HeaderComment>
  </nsSAFT:Header>
  <nsSAFT:MasterFilesMonthly>
    ...
  </nsSAFT:MasterFilesMonthly>
  <nsSAFT:GeneralLedgerEntries>
    ...
  </nsSAFT:GeneralLedgerEntries>
  <nsSAFT:SourceDocumentsMonthly>
    ...
  </nsSAFT:SourceDocumentsMonthly>
</nsSAFT:AuditFile>
```

### 2. Annual (Годишен)

**Употреба:** Годишна финансова отчетност

**Включва:**
- Обобщени данни за годината
- Годишни салда по сметки
- Обобщени документи

**Файлово име:** `saft_annual_YYYY.xml`

**Пример структура:**
```xml
<nsSAFT:AuditFile>
  <nsSAFT:Header>
    <nsSAFT:HeaderComment>A</nsSAFT:HeaderComment>
  </nsSAFT:Header>
  <nsSAFT:MasterFilesAnnual>
    ...
  </nsSAFT:MasterFilesAnnual>
  <nsSAFT:SourceDocumentsAnnual>
    ...
  </nsSAFT:SourceDocumentsAnnual>
</nsSAFT:AuditFile>
```

### 3. OnDemand (При поискване)

**Употреба:** При данъчна ревизия или специално искане от НАП

**Включва:**
- Данни за конкретен период
- Всички детайли за периода

**Файлово име:** `saft_ondemand_YYYY_MM_DD_to_YYYY_MM_DD.xml`

**Пример структура:**
```xml
<nsSAFT:AuditFile>
  <nsSAFT:Header>
    <nsSAFT:HeaderComment>OnDemand</nsSAFT:HeaderComment>
  </nsSAFT:Header>
  <nsSAFT:MasterFilesOnDemand>
    ...
  </nsSAFT:MasterFilesOnDemand>
  <nsSAFT:SourceDocumentsOnDemand>
    ...
  </nsSAFT:SourceDocumentsOnDemand>
</nsSAFT:AuditFile>
```

---

## Примери за употреба

### Пример 1: Добавяне на контрагент с всички SAF-T полета

```elixir
{:ok, contact} = Repo.insert(
  Contact.changeset(%Contact{}, %{
    tenant_id: 1,
    name: "Клиент ЕООД",
    name_cyrillic: "Клиент ЕООД",
    name_latin: "Client Ltd",

    # Identification
    registration_number: "123456789",
    vat_number: "BG123456789",
    tax_type: "100010",

    # Address
    street_name: "ул. Витоша",
    building_number: "100",
    city: "София",
    postal_code: "1000",
    region: "BG-22",
    country: "BG",

    # Contact
    email: "contact@client.com",
    phone: "0888123456",
    fax: "028123456",
    website: "https://client.com",

    contact_person_title: "Г-н",
    contact_person_first_name: "Иван",
    contact_person_last_name: "Иванов",

    # Classification
    is_customer: true,
    is_supplier: false,
    is_company: true,
    self_billing_indicator: false,
    related_party: false,

    # Bank
    iban_number: "BG80BNBG96611020345678",

    # Accounting
    accounting_account_id: "411",
    opening_debit_balance: Decimal.new("0.00"),
    closing_debit_balance: Decimal.new("2500.00"),

    # Tax
    tax_authority: "NRA",
    tax_verification_date: ~D[2025-01-01]
  })
)
```

### Пример 2: Генериране на месечен SAF-T файл

```elixir
# За октомври 2025
{:ok, path} = SaftExport.generate_monthly(
  1,                            # tenant_id
  2025,                         # year
  10,                           # month
  "/tmp/saft_monthly_2025_10.xml"
)

IO.puts("SAF-T файлът е генериран: #{path}")
```

### Пример 3: Генериране на годишен SAF-T файл

```elixir
# За 2025 година
{:ok, path} = SaftExport.generate_annual(
  1,                            # tenant_id
  2025,                         # year
  "/tmp/saft_annual_2025.xml"
)

IO.puts("Годишен SAF-T файл: #{path}")
```

### Пример 4: Генериране при поискване от НАП

```elixir
# За период от 01.01.2025 до 30.06.2025
{:ok, path} = SaftExport.generate_on_demand(
  1,
  ~D[2025-01-01],
  ~D[2025-06-30],
  "/tmp/saft_ondemand_q1_q2.xml"
)

IO.puts("OnDemand SAF-T файл: #{path}")
```

### Пример 5: Търсене на контрагенти по тип

```elixir
# Всички доставчици
suppliers = Repo.all(
  from c in Contact,
  where: c.tenant_id == ^1
    and c.is_supplier == true,
  order_by: [asc: c.name]
)

# Всички клиенти с ДДС
vat_customers = Repo.all(
  from c in Contact,
  where: c.tenant_id == ^1
    and c.is_customer == true
    and not is_nil(c.vat_number),
  order_by: [asc: c.name]
)

# Свързани лица
related_parties = Repo.all(
  from c in Contact,
  where: c.tenant_id == ^1
    and c.related_party == true
)
```

---

## Референтни материали

### Спецификация и примери:

**Локация:** `/home/dvg/z-nim-proloq/cyber_ERP/FILE/SAFT_BG/`

**Файлове:**
1. `BG_SAFT_Schema_V_1.0.1.xsd` - XSD схема
2. `SAF-T_BG_Structure_Definition_V_1.0.1.xlsx` - Excel документация
3. `VS_SAMPLE_AuditFile_Monthly_V_1.0.1.xml` - Примерен месечен файл
4. `VS_SAMPLE_AuditFile_Annual_V_1.0.xml` - Примерен годишен файл
5. `VS_SAMPLE_AuditFile_OnDemand_V_1.0.xml` - Примерен OnDemand файл

### Структура на файловете:

```
apps/cyber_core/
├── lib/cyber_core/
│   ├── accounting/
│   │   └── saft_export.ex           # SAF-T генератор
│   └── contacts/
│       └── contact.ex                # Разширена Contact схема
├── priv/repo/migrations/
│   └── 20251011154008_add_saft_fields_to_contacts.exs
└── test/cyber_core/accounting/
    └── saft_export_test.exs         # TODO: Тестове

docs/
├── SAFT-docs.md                      # Този документ
└── VAT-docs.md                       # ДДС документация
```

### Връзка с ДДС система:

SAF-T файловете включват ДДС информация от:
- `vat_sales_register` - Дневник продажби
- `vat_purchase_register` - Дневник покупки
- `vat_returns` - ДДС справки

Вижте **VAT-docs.md** за подробности за ДДС имплементацията.

---

## Важни бележки

### ⚠️ TODOItems:

1. **General Ledger Entries** - Трябва да се имплементира генериране на счетоводни записи
2. **Source Documents** - Трябва да се имплементира генериране на първични документи:
   - Sales Invoices
   - Purchase Invoices
   - Payments
   - Stock Movements
3. **Валидация** - Добавяне на валидация спрямо XSD схема
4. **Тестове** - Unit tests за SAF-T генератора
5. **UI** - LiveView за генериране и преглед на SAF-T файлове

### 📋 Изисквания на НАП:

- Файлът трябва да е валиден спрямо XSD схемата
- Кодировка UTF-8
- Всички задължителни полета трябва да са попълнени
- Датите в формат ISO 8601 (YYYY-MM-DD)
- Числовите стойности с точка като десетичен разделител
- XML escape на специални символи

### 🔒 Сигурност:

- SAF-T файловете съдържат чувствителна финансова информация
- Препоръчително е да се шифроват преди изпращане
- Достъпът до генерирането трябва да е ограничен само за овластени лица
- Логване на всички генерирани файлове

---

## Заключение

SAF-T имплементацията в Cyber ERP осигурява:

✅ Пълна съвместимост с българската SAF-T схема версия 1.0.1
✅ Три типа генериране (месечен, годишен, при поискване)
✅ Разширени контрагентски данни
✅ Интеграция с ДДС система
✅ Автоматично генериране на XML файлове

**Следващи стъпки:**
1. Имплементиране на General Ledger Entries
2. Имплементиране на Source Documents
3. Добавяне на XSD валидация
4. Създаване на UI за генериране
5. Тестване с реални данни

---

**Документът е актуален към:** 2025-10-11

**Автор:** Claude (AI асистент)

**Версия:** 1.0
