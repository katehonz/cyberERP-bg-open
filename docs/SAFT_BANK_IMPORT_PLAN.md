# SAF-T & Bank Import Module Plan за CyberERP

## Цел
Създаване на backend модул подобен на rs-ac-bg-main за:
1. Импорт на банкови извлечения (MT940, CAMT053, CSV, XML)
2. SAF-T валидация и генериране
3. Номенклатурни справочници

## Архитектура (по модел на rs-ac-bg-main)

### 1. SAF-T Nomenclatures (Номенклатури)

#### 1.1 Schema-и и Миграции

```elixir
# apps/cyber_core/lib/cyber_core/saft/nomenclature/
├── iban_format.ex              # IBAN формати по държави
├── invoice_type.ex             # Видове фактури (01-95)
├── payment_method.ex           # Механизми за плащане
├── movement_type.ex            # Движение на стоки
├── asset_movement_type.ex      # Движение на активи
├── vat_tax_type.ex             # ДДС режими
├── inventory_type.ex           # Видове материални запаси
└── tax_code.ex                 # Данъчни кодове
```

**Migrations**:
```bash
mix ecto.gen.migration create_saft_nomenclatures
mix ecto.gen.migration create_saft_invoice_types
mix ecto.gen.migration create_saft_payment_methods
mix ecto.gen.migration create_saft_iban_formats
```

#### 1.2 Seeds

```elixir
# priv/repo/seeds/saft_nomenclatures.exs
- Import всички CSV файлове от FILE/SAFT_BG/
- IBAN formats
- Invoice types (01-95)
- Payment methods (01-03 + механизми 10, 20, 30, 42, 48, 68, 97-99)
- Movement types
- VAT tax types
```

### 2. Bank Import Module

#### 2.1 Entities (Schemas)

```elixir
# apps/cyber_core/lib/cyber_core/bank/

## BankProfile
- tenant_id
- name (напр. "Уникредит - BGN")
- iban
- bank_account_id (foreign key → accounts)
- buffer_account_id (foreign key → accounts)
- currency_code
- import_format (enum: mt940, camt053_wise, camt053_revolut, ccb_csv, xml)
- is_active
- settings (jsonb)

## BankImport
- tenant_id
- bank_profile_id
- file_name
- import_format
- imported_at
- transactions_count
- total_credit
- total_debit
- created_journal_entries
- journal_entry_ids (array of integers)
- status (enum: in_progress, completed, failed)
- error_message
- created_by
- timestamps

## BankTransaction (embedded schema, not persisted)
- booking_date
- value_date
- amount
- currency
- is_credit
- description
- reference
```

#### 2.2 Services

```elixir
# apps/cyber_core/lib/cyber_core/bank/

## ImportService
defmodule CyberCore.Bank.ImportService do
  @supported_formats [:mt940, :camt053_wise, :camt053_revolut, :ccb_csv, :xml]

  def import_statement(profile, file_name, file_content, created_by)
  def supported_formats()
  defp decode_to_string(content, format)
  defp parse_transactions(content, format, profile)
  defp persist_transactions(txn, profile, file_name, transactions, created_by)
end

## Parsers Module
defmodule CyberCore.Bank.Parsers do
  def parse_mt940(content, currency)
  def parse_camt053(content) # XML parsing
  def parse_ccb_csv(content, currency)
  def parse_postbank_xml(content, currency)
end

## TransactionParser (AI-powered)
defmodule CyberCore.Bank.TransactionParser do
  # Mistral API integration за извличане на контрагенти
  def parse_transaction_description(db, description)
  defp invoke_mistral_parser(api_key, model, description)
  defp parse_mistral_response(raw)
end
```

#### 2.3 Context API

```elixir
# apps/cyber_core/lib/cyber_core/bank.ex
defmodule CyberCore.Bank do
  # BankProfile CRUD
  def list_bank_profiles(tenant_id)
  def get_bank_profile!(tenant_id, id)
  def create_bank_profile(attrs)
  def update_bank_profile(profile, attrs)
  def delete_bank_profile(profile)

  # Import operations
  def import_statement(profile, file_name, content, user_id)
  def list_bank_imports(tenant_id, opts \\ [])
  def get_bank_import!(tenant_id, id)

  # Helper
  def supported_import_formats()
end
```

### 3. SAF-T Module

#### 3.1 Entities

```elixir
# apps/cyber_core/lib/cyber_core/saft/

## SAF-T Structures (Embedded schemas for XML generation)
├── header.ex
├── company_info.ex
├── selection_criteria.ex
├── master_files/
│   ├── annual.ex
│   ├── monthly.ex
│   └── on_demand.ex
├── general_ledger_entries.ex
└── source_documents/
    ├── annual.ex
    ├── monthly.ex
    └── on_demand.ex
```

#### 3.2 Generator

```elixir
# apps/cyber_core/lib/cyber_core/saft/generator.ex
defmodule CyberCore.SAFт.Generator do
  @moduledoc """
  SAF-T XML generator съгласно българските изисквания v1.0.1
  """

  def generate_saft(company_id, request) do
    # 1. Build header
    # 2. Build master files based on type
    # 3. Build source documents
    # 4. Generate XML using XmlBuilder
  end

  defp build_header(company, request)
  defp build_master_files_annual(request)
  defp build_master_files_monthly(request)
  defp build_general_ledger_entries(request)
  defp build_source_documents(request)
  defp generate_xml(saft_struct)
end
```

#### 3.3 Validator

```elixir
# apps/cyber_core/lib/cyber_core/saft/validator.ex
defmodule CyberCore.SAFт.Validator do
  @moduledoc """
  Валидация на SAF-T данни според номенклатурите
  """

  def validate_iban(iban, country)
  def validate_invoice_type(code)
  def validate_payment_method(code)
  def validate_cn_code(code, year)
  def validate_eik(eik)
  def validate_vat_number(vat)
end
```

### 4. Validators Module

```elixir
# apps/cyber_core/lib/cyber_core/validators/

## IBANValidator
defmodule CyberCore.Validators.IBAN do
  def validate(iban)
  def validate_format(iban, country_code)
  def checksum_valid?(iban)
  def parse(iban) # Returns: country, check_digits, bank_code, account
end

## EIKValidator
defmodule CyberCore.Validators.EIK do
  def validate(eik)
  def checksum_valid?(eik)
end

## VATValidator
defmodule CyberCore.Validators.VAT do
  def validate(vat, country \\ "BG")
end
```

## Implementation Steps

### Phase 1: Nomenclatures (Week 1)
- [x] ~~ETS Cache готов~~
- [ ] Create migrations за SAF-T nomenclatures
- [ ] Create schemas
- [ ] Import CSV данни в seeds
- [ ] Validators за номенклатури

### Phase 2: Bank Import (Week 2)
- [ ] BankProfile schema + migrations
- [ ] BankImport schema + migrations
- [ ] MT940 parser
- [ ] CAMT053 parser (XML)
- [ ] CSV parser (CCB)
- [ ] ImportService logic
- [ ] Journal entry creation от transactions

### Phase 3: AI Integration (Week 3)
- [ ] Mistral API integration
- [ ] TransactionParser service
- [ ] Counterpart extraction
- [ ] Settings за API keys

### Phase 4: SAF-T Generator (Week 4)
- [ ] Header builder
- [ ] Master Files builders
- [ ] Source Documents builders
- [ ] XML generator (using XmlBuilder или SweetXml)
- [ ] XSD validation

### Phase 5: LiveView UI (Week 5-6)
- [ ] BankProfile management
- [ ] File upload за bank statements
- [ ] Import history view
- [ ] SAF-T export UI
- [ ] Preview и download

## Dependencies

```elixir
# mix.exs additions
defp deps do
  [
    # Existing...

    # XML parsing/generation
    {:sweet_xml, "~> 0.7"},
    {:xml_builder, "~> 2.2"},

    # CSV parsing
    {:csv, "~> 3.2"},

    # HTTP client за Mistral API
    {:req, "~> 0.5"},

    # Character encoding
    {:codepagex, "~> 0.1"}
  ]
end
```

## Files структура

```
apps/cyber_core/lib/cyber_core/
├── bank/
│   ├── bank_profile.ex
│   ├── bank_import.ex
│   ├── import_service.ex
│   ├── transaction_parser.ex
│   └── parsers/
│       ├── mt940.ex
│       ├── camt053.ex
│       ├── csv.ex
│       └── xml.ex
├── saft/
│   ├── nomenclature/
│   │   ├── iban_format.ex
│   │   ├── invoice_type.ex
│   │   ├── payment_method.ex
│   │   └── ...
│   ├── structures/
│   │   ├── header.ex
│   │   ├── company_info.ex
│   │   └── ...
│   ├── generator.ex
│   └── validator.ex
├── validators/
│   ├── iban.ex
│   ├── eik.ex
│   └── vat.ex
└── bank.ex (context)

apps/cyber_web/lib/cyber_web/
└── live/
    ├── bank_profile_live/
    │   ├── index.ex
    │   ├── form_component.ex
    │   └── show.ex
    ├── bank_import_live/
    │   ├── index.ex
    │   └── upload_component.ex
    └── saft_live/
        ├── index.ex
        └── export_component.ex
```

## Testing Strategy

```elixir
# Test files
test/cyber_core/
├── bank/
│   ├── import_service_test.exs
│   ├── parsers/
│   │   ├── mt940_test.exs
│   │   └── camt053_test.exs
│   └── transaction_parser_test.exs
├── saft/
│   ├── generator_test.exs
│   └── validator_test.exs
└── validators/
    ├── iban_test.exs
    └── eik_test.exs
```

## Sample Data

```
test/fixtures/
├── bank_statements/
│   ├── unicredit_mt940.txt
│   ├── wise_camt053.xml
│   ├── revolut_camt053.xml
│   └── ccb_statement.csv
└── saft/
    ├── valid_monthly.xml
    └── valid_annual.xml
```

## Next Steps

1. ✅ ETS Cache - DONE
2. Create migrations за nomenclatures
3. Import CSV данни
4. Implement BankProfile + BankImport schemas
5. MT940 parser (най-често използван в БГ)
6. Basic ImportService
7. LiveView за upload на файлове

Започваме? 🚀
