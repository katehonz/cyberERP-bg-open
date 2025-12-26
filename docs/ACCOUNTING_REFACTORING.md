# Рефакторинг на счетоводството за SAF-T съвместимост

## Преглед

Този документ описва рефакторинга на счетоводния модул на CyberERP за пълна съвместимост със SAF-T (Standard Audit File for Tax) стандарта на НАП.

## Дата на промените

**2025-11-21**

## Основни промени

### 1. Аналитично счетоводство с контрагенти

#### Промени в `EntryLine` (apps/cyber_core/lib/cyber_core/accounting/entry_line.ex)

Добавена е връзка към контрагенти за всяка счетоводна транзакция:

```elixir
# Нова релация
belongs_to :contact, CyberCore.Contacts.Contact, foreign_key: :contact_id

# Ново поле в changeset
:contact_id
```

**Миграция:** `20251121182056_refactor_contact_accounting.exs`
```elixir
alter table(:entry_lines) do
  add :contact_id, references(:contacts, on_delete: :nothing)
end
```

**SAF-T Изискване:**
SAF-T стандартът изисква информация за контрагента (`CustomerID` / `SupplierID`) при всяка транзакция с аналитични сметки (401, 411, и т.н.). Това е задължително поле в секция `GeneralLedgerEntries`.

#### Как работи:

1. Когато потребителят избере аналитична сметка (напр. 401 - Доставчици), формата автоматично показва поле за избор на контрагент
2. `is_analytical` флагът на сметката определя дали е нужен контрагент
3. Данните се записват в `entry_lines.contact_id`

### 2. Правилни Foreign Keys в Contacts

#### Промени в `Contact` (apps/cyber_core/lib/cyber_core/contacts/contact.ex)

Променено от string поле към правилна database релация:

```elixir
# ПРЕДИ:
field :accounting_account_id, :string   # Проблем: няма референциална интегритет

# СЛЕД:
belongs_to :accounting_account, Account, foreign_key: :accounting_account_id
```

**Миграции:**
1. `20251121182056_refactor_contact_accounting.exs` - премахва старото поле
2. `20251121182757_add_accounting_account_to_contacts.exs` - добавя правилна foreign key

```elixir
alter table(:contacts) do
  remove :accounting_account_id  # Премахва string полето
end

alter table(:contacts) do
  add :accounting_account_id, references(:accounts, on_delete: :nilify_all)
end
```

**Ползи:**
- Референциална интегритет на базата данни
- Невъзможност за невалидни референции към несъществуващи сметки
- Автоматично `nilify_all` при изтриване на сметка (вместо orphan records)
- Възможност за `preload` и join queries

### 3. Централизирани счетоводни настройки

С цел по-голяма гъвкавост и по-лесна конфигурация, реконсилиационните сметки за контрагентите и други сметки по подразбиране са изнесени в централизирани счетоводни настройки.

#### Промени в `Contact` (apps/cyber_core/lib/cyber_core/contacts/contact.ex)

Премахнато е полето `accounting_account_id` от контрагентите. Вместо всеки контрагент да има индивидуална реконсилиационна сметка, вече се използват сметките по подразбиране от настройките.

#### Нова таблица `accounting_settings`

Създадена е нова таблица `accounting_settings` за съхранение на счетоводните настройки за всеки tenant.

**Миграция:** `20251202153644_create_accounting_settings.exs`
```elixir
create table(:accounting_settings) do
  add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
  add :suppliers_account_id, references(:accounts, on_delete: :nothing)
  add :customers_account_id, references(:accounts, on_delete: :nothing)
  add :cash_account_id, references(:accounts, on_delete: :nothing)
  add :vat_sales_account_id, references(:accounts, on_delete: :nothing)
  add :vat_purchases_account_id, references(:accounts, on_delete: :nothing)
  add :default_income_account_id, references(:accounts, on_delete: :nothing)
  # ... and more fields for inventory and WIP
end
```

#### Как работи:

1.  **Нов таб в настройките:** В `/settings` е добавен нов таб "Счетоводство".
2.  **Конфигурация:** Потребителите могат да изберат сметки по подразбиране за:
    -   Доставчици (напр. 401)
    -   Клиенти (напр. 411)
    -   ДДС Продажби (напр. 4532)
    -   ДДС Покупки (напр. 4531)
    -   Приходи, Стоки, Материали, и др.
3.  **Автоматично осчетоводяване:** При автоматично създаване на фактури (например от AI обработка), системата използва тези настройки за генериране на правилните счетоводни записвания.

### 4. Подобрена форма за журнални записи

#### Промени в `FormComponent` (apps/cyber_web/lib/cyber_web/live/journal_entry_live/form_component.ex)

**Добавени полета:**
- `contact_id` - ID на контрагента
- `is_analytical` - флаг дали сметката е аналитична

**Логика:**
```elixir
# Когато се избере сметка, автоматично се определя дали е аналитична
if field == :account_id do
  account = Enum.find(socket.assigns.accounts, &(&1.id == String.to_integer(value)))
  line
  |> Map.put(:account_id, value)
  |> Map.put(:is_analytical, account && account.is_analytical)
end
```

**UI:**
- Dropdown за контрагенти се показва само ако сметката е аналитична
- В противен случай се показва "-"
- Списък с всички контакти се зарежда при mount на формата

### 4. SAF-T Nomenclatures Viewer

#### Нов модул: `NomenclatureLive.Index` (apps/cyber_web/lib/cyber_web/live/nomenclature_live/index.ex)

LiveView за преглед на всички SAF-T номенклатури директно в уеб интерфейса.

**Функционалност:**
- Зарежда всички 14 задължителни SAF-T номенклатури от CSV файлове
- Интелигентно откриване на header редове (търси ключови думи като "Код", "Описание", "Име")
- Fallback логика за CSV файлове с нестандартна структура
- Error handling и logging

**Поддържани номенклатури:**
1. Номенклатури (общ списък)
2. AssetMovementTypes (движения на активи)
3. IBAN-ISO13616-1997 (IBAN формати)
4. ISO3166-1-CountryCodes (кодове на държави)
5. ISO3166-2BG - Area Codes (области в България)
6. ISO4217CurrCodes (валути)
7. NC8_TARIC (комбинирана номенклатура)
8. Nom_Inventory_Types (видове материални запаси)
9. Nom_Invoice_Types (видове фактури)
10. Nom_PaymentMethod (методи за плащане)
11. NRA_Nom_Accounts (счетоводни сметки на НАП)
12. Unit of Measure (мерни единици)
13. VAT_TaxType (данъчни режими за ДДС)

**Достъп:**
```
/nomenclatures
```

## SAF-T Compliance

### GeneralLedgerEntries структура

Рефакторингът позволява правилно генериране на SAF-T XML секция за счетоводни записи:

```xml
<GeneralLedgerEntries>
  <JournalEntry>
    <JournalID>001</JournalID>
    <Description>Доставка стоки</Description>
    <TransactionDate>2025-11-21</TransactionDate>
    <Line>
      <RecordID>1</RecordID>
      <AccountID>401001</AccountID>
      <SupplierID>1234567890</SupplierID>  <!-- От contact_id -->
      <DebitAmount>
        <Amount>1000.00</Amount>
        <CurrencyCode>BGN</CurrencyCode>
      </DebitAmount>
    </Line>
  </JournalEntry>
</GeneralLedgerEntries>
```

### Изисквания от НАП

Съгласно SAF-T BG спецификация версия 1.0.1:

1. **Задължителни полета при аналитични сметки:**
   - `CustomerID` - за сметки 411 (Клиенти)
   - `SupplierID` - за сметки 401 (Доставчици)

2. **Счетоводен план:**
   - Използване на стандартния сметкоплан на НАП
   - Сметки трябва да са референции към `NRA_Nom_Accounts` номенклатурата

3. **Контрагенти:**
   - Уникален ID за всеки контрагент
   - Връзка със счетоводната сметка
   - ДДС номер (ако е приложимо)

## Миграция на данни

### За съществуващи инсталации

Ако имате съществуващи данни в `contacts.accounting_account_id` като string:

1. Backup на базата данни
2. Конвертиране на string ID към integer foreign key:

```elixir
# Migration script (ако е необходимо)
defmodule CyberCore.Repo.Migrations.MigrateAccountingAccountIds do
  use Ecto.Migration
  import Ecto.Query
  alias CyberCore.Repo

  def up do
    # Първо мапваме string account codes към integer IDs
    # Примерно: "401" -> account.id където account.code == "401"

    from(c in "contacts",
      join: a in "accounts",
      on: c.accounting_account_id == a.code,
      update: [set: [accounting_account_id: a.id]]
    )
    |> Repo.update_all([])
  end
end
```

## Testing

### Тестови сценарии

1. **Създаване на журнален запис с аналитична сметка:**
   - Избор на сметка 401
   - Форматa показва поле за контрагент
   - Избор на доставчик
   - Записът се създава с `contact_id`

2. **Създаване на журнален запис с неаналитична сметка:**
   - Избор на сметка 503 (Разходи за стоки)
   - Полето за контрагент НЕ се показва
   - Записът се създава без `contact_id`

3. **Преглед на номенклатури:**
   - Отваряне на `/nomenclatures`
   - Всички CSV файлове се зареждат и парсват коректно
   - Headers и data rows се показват правилно

## Известни проблеми

Няма известни проблеми към момента.

## TODO (бъдещи подобрения)

- [ ] Валидация че аналитичните сметки ЗАДЪЛЖИТЕЛНО имат контрагент
- [ ] Автоматично създаване на контрагенти от SAF-T import
- [ ] UI за управление на номенклатурите (добавяне/редакция)
- [ ] Кеширане на парсванит номенклатури за по-бърза зареждане
- [ ] Экспорт на номенклатури към различни формати (JSON, Excel)

## Референции

- [SAF-T BG Specification v1.0.1](../FILE/SAFT_BG/)
- [NOMENCLATURES.md](../NOMENCLATURES.md) - Обща документация за номенклатури
- [SAFT-docs.md](./SAFT-docs.md) - SAF-T имплементация в CyberERP

## Автори

- DVG - Initial refactoring
- Claude AI - Documentation assistance

## История на промените

| Дата | Версия | Описание |
|------|--------|----------|
| 2025-11-21 | 1.0 | Първоначален рефакторинг за SAF-T съвместимост |
