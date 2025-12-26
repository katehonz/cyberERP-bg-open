# SAF-T към Схема на База Данни - Мапинг

Този документ описва мапинга между полетата в SAF-T XML файла и схемата на базата данни на приложението `cyber_erp`.

## `<Header>`

| SAF-T Поле                  | Таблица/Колона в `cyber_erp`                                | Логика/Бележки                                                              |
| --------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------- |
| `AuditFileVersion`          | -                                                          | Хардкодвана стойност: "007"                                                 |
| `AuditFileCountry`          | -                                                          | Хардкодвана стойност: "BG"                                                  |
| `AuditFileRegion`           | -                                                          | Хардкодвана стойност: "BG-22"                                               |
| `AuditFileDateCreated`      | -                                                          | Текуща дата на генериране на файла.                                         |
| `SoftwareCompanyName`       | -                                                          | Хардкодвана стойност или от конфигурационен файл.                           |
| `SoftwareID`                | -                                                          | Хардкодвана стойност или от конфигурационен файл.                           |
| `SoftwareVersion`           | -                                                          | Версия на приложението.                                                     |
| `Company.RegistrationNumber`| `tenants.uic`                                              |                                                                             |
| `Company.Name`              | `tenants.name`                                             |                                                                             |
| `Company.Address`           | `tenants` (свързани адреси)                                | Ще е необходимо да се имплементира връзка към адреси за `tenants`.          |
| `Company.Contact`           | `tenants` (свързани контакти)                              | Ще е необходимо да се имплементира връзка към контакти за `tenants`.         |
| `Company.TaxRegistration`   | `tenants.vat_number`                                       |                                                                             |
| `Company.BankAccount`       | `bank_accounts`                                            |                                                                             |
| `Ownership`                 | `tenants` (информация за собственост)                       | Ще е необходимо да се добавят полета за собственост в `tenants` таблицата. |
| `DefaultCurrencyCode`       | `tenants.base_currency`                                    |                                                                             |
| `SelectionCriteria`         | -                                                          | Попълва се на база на потребителски вход при генериране на файла.           |
| `HeaderComment`             | -                                                          | Хардкодвана стойност "M" за месечен отчет.                                  |
| `TaxAccountingBasis`        | -                                                          | Хардкодвана стойност "A" за търговски предприятия.                          |
| `TaxEntity`                 | -                                                          |                                                                             |

## `<MasterFilesMonthly>`

### `<GeneralLedgerAccounts>`

| SAF-T Поле                | Таблица/Колона в `cyber_erp` | Логика/Бележки                                           |
| ------------------------- | ---------------------------- | -------------------------------------------------------- |
| `Account.AccountID`       | `accounts.number`            |                                                          |
| `Account.AccountDescription`| `accounts.name`              |                                                          |
| `Account.TaxpayerAccountID`| `accounts.number`            |                                                          |
| `Account.GroupingCategory`| `accounts.type`              |                                                          |
| `Account.AccountType`     | `accounts.type`              | Ще е нужна трансформация към "Active", "Passive", "Bifunctional". |
| `Account.OpeningDebitBalance`| `journal_entries`         | Сума на дебитните транзакции преди началото на периода. |
| `Account.OpeningCreditBalance`| `journal_entries`        | Сума на кредитните транзакции преди началото на периода. |
| `Account.ClosingDebitBalance`| `journal_entries`         | Сума на дебитните транзакции в края на периода.         |
| `Account.ClosingCreditBalance`| `journal_entries`        | Сума на кредитните транзакции в края на периода.         |

### `<Customers>`

| SAF-T Поле                     | Таблица/Колона в `cyber_erp` | Логика/Бележки                                                         |
| ------------------------------ | ---------------------------- | ---------------------------------------------------------------------- |
| `Customer.CompanyStructure`    | `contacts`                   | Информация за клиента (име, адрес, и т.н.)                           |
| `Customer.CustomerID`          | `contacts.vat_number`        |                                                                        |
| `Customer.AccountID`           | `contacts.account_id`        |                                                                        |
| `Customer.OpeningDebitBalance` | `invoice_lines`              | Сума на дебитните салда на клиента в началото на периода.             |
| `Customer.ClosingDebitBalance` | `invoice_lines`              | Сума на дебитните салда на клиента в края на периода.                 |

### `<Suppliers>`

| SAF-T Поле                     | Таблица/Колона в `cyber_erp`     | Логика/Бележки                                                        |
| ------------------------------ | -------------------------------- | --------------------------------------------------------------------- |
| `Supplier.CompanyStructure`    | `contacts`                       | Информация за доставчика (име, адрес, и т.н.)                        |
| `Supplier.SupplierID`          | `contacts.vat_number`            |                                                                       |
| `Supplier.AccountID`           | `contacts.account_id`            |                                                                       |
| `Supplier.OpeningCreditBalance`| `supplier_invoice_lines`         | Сума на кредитните салда на доставчика в началото на периода.        |
| `Supplier.ClosingCreditBalance`| `supplier_invoice_lines`         | Сума на кредитните салда на доставчика в края на периода.            |

### `<TaxTable>`

| SAF-T Поле                  | Таблица/Колона в `cyber_erp` | Логика/Бележки                                                              |
| --------------------------- | ---------------------------- | --------------------------------------------------------------------------- |
| `TaxTableEntry.TaxType`     | `vat_codes.code`             |                                                                             |
| `TaxTableEntry.Description` | `vat_codes.description`      |                                                                             |
| `TaxCodeDetails.TaxCode`    | `vat_codes.code`             |                                                                             |
| `TaxCodeDetails.Description`| `vat_codes.description`      |                                                                             |
| `TaxCodeDetails.TaxPercentage`| `vat_codes.rate`           |                                                                             |

### `<UOMTable>`

| SAF-T Поле                    | Таблица/Колона в `cyber_erp` | Логика/Бележки |
| ----------------------------- | ---------------------------- | -------------- |
| `UOMTableEntry.UnitOfMeasure` | `measurement_units.code`     |                |
| `UOMTableEntry.Description`   | `measurement_units.name`     |                |

### `<Products>`

| SAF-T Поле                       | Таблица/Колона в `cyber_erp` | Логика/Бележки                               |
| -------------------------------- | ---------------------------- | -------------------------------------------- |
| `Product.ProductCode`            | `products.code`              |                                              |
| `Product.ProductGroup`           | `products.group`             |                                              |
| `Product.Description`            | `products.name`              |                                              |
| `Product.ProductCommodityCode`   | `products.cn_code`           |                                              |
| `Product.UOMBase`                | `product_units.unit_id`      |                                              |
| `Product.Tax`                    | `products.vat_code_id`       |                                              |

## `<GeneralLedgerEntries>`

| SAF-T Поле                            | Таблица/Колона в `cyber_erp`  | Логика/Бележки                               |
| ------------------------------------- | ----------------------------- | -------------------------------------------- |
| `Journal.Transaction.TransactionID`   | `journal_entries.id`          |                                              |
| `Journal.Transaction.Period`          | `journal_entries.entry_date`  | Месец от датата.                             |
| `Journal.Transaction.PeriodYear`      | `journal_entries.entry_date`  | Година от датата.                            |
| `Journal.Transaction.TransactionDate` | `journal_entries.entry_date`  |                                              |
| `Journal.Transaction.SourceID`        | `journal_entries.source`      |                                              |
| `Journal.Transaction.Description`     | `journal_entries.description` |                                              |
| `TransactionLine.RecordID`            | `journal_lines.id`            |                                              |
| `TransactionLine.AccountID`           | `journal_lines.account_id`    |                                              |
| `TransactionLine.CustomerID`          | `journal_lines.contact_id`    | Ако `contact_type` е 'Customer'.               |
| `TransactionLine.SupplierID`          | `journal_lines.contact_id`    | Ако `contact_type` е 'Supplier'.               |
| `TransactionLine.Description`         | `journal_lines.description`   |                                              |
| `TransactionLine.DebitAmount`         | `journal_lines.debit`         |                                              |
| `TransactionLine.CreditAmount`        | `journal_lines.credit`        |                                              |
| `TransactionLine.TaxInformation`      | `journal_lines.vat_code_id`   |                                              |

## `<SourceDocumentsMonthly>`

### `<SalesInvoices>`

| SAF-T Поле                      | Таблица/Колона в `cyber_erp` | Логика/Бележки |
| ------------------------------- | ---------------------------- | -------------- |
| `Invoice.InvoiceNo`             | `invoices.invoice_number`    |                |
| `Invoice.CustomerInfo`          | `contacts`                   |                |
| `Invoice.InvoiceDate`           | `invoices.invoice_date`      |                |
| `Invoice.InvoiceType`           | `invoices.document_type`     |                |
| `InvoiceLine.ProductCode`       | `invoice_lines.product_id`   |                |
| `InvoiceLine.Quantity`          | `invoice_lines.quantity`     |                |
| `InvoiceLine.UnitPrice`         | `invoice_lines.unit_price`   |                |
| `InvoiceLine.InvoiceLineAmount` | `invoice_lines.total_price`  |                |
| `InvoiceLine.TaxInformation`    | `invoice_lines.vat_code_id`  |                |

### `<PurchaseInvoices>`

| SAF-T Поле                      | Таблица/Колона в `cyber_erp`       | Логика/Бележки |
| ------------------------------- | ---------------------------------- | -------------- |
| `Invoice.InvoiceNo`             | `supplier_invoices.invoice_number` |                |
| `Invoice.SupplierInfo`          | `contacts`                         |                |
| `Invoice.InvoiceDate`           | `supplier_invoices.invoice_date`   |                |
| `Invoice.InvoiceType`           | `supplier_invoices.document_type`  |                |
| `InvoiceLine.ProductCode`       | `supplier_invoice_lines.product_id`|                |
| `InvoiceLine.Quantity`          | `supplier_invoice_lines.quantity`  |                |
| `InvoiceLine.UnitPrice`         | `supplier_invoice_lines.unit_price`|                |
| `InvoiceLine.InvoiceLineAmount` | `supplier_invoice_lines.total_price`|                |
| `InvoiceLine.TaxInformation`    | `supplier_invoice_lines.vat_code_id`|                |

### `<Payments>`

| SAF-T Поле                  | Таблица/Колона в `cyber_erp` | Логика/Бележки |
| --------------------------- | ---------------------------- | -------------- |
| `Payment.PaymentRefNo`      | `bank_transactions.id`       |                |
| `Payment.TransactionDate`   | `bank_transactions.transaction_date` |       |
| `Payment.PaymentMethod`     | `bank_transactions.payment_method` |         |
| `PaymentLine.SourceDocumentID`| `bank_transactions.invoice_id` |             |
| `PaymentLine.PaymentLineAmount`| `bank_transactions.amount` |               |
