# SAF-T Годишен файл за дълготрайни активи (ДМА)

## Описание

Имплементирана е пълна функционалност за генериране на SAF-T годишен файл за дълготрайни материални активи (ДМА) според изискванията на НАП.

## Основни компоненти

### 1. AssetTransaction - Транзакции с активи

Новата таблица `asset_transactions` записва всички движения на активи за SAF-T отчитането.

**Типове транзакции:**
- `10` - ACQ (Acquisition) - Придобиване
- `20` - IMP (Improvement) - Подобрение/Увеличаване на стойност
- `30` - DEP (Depreciation) - Амортизация
- `40` - REV (Revaluation) - Преоценка
- `50` - DSP (Disposal) - Продажба
- `60` - SCR (Scrap) - Брак/Отписване
- `70` - TRF (Transfer) - Вътрешен трансфер
- `80` - COR (Correction) - Корекция

### 2. Разширени полета в Asset модела

**За SAF-T ValuationDAP (Данъчен амортизационен план):**
- `month_value_change` - Месец на промяна на стойността
- `month_suspension_resumption` - Месец на спиране/възобновяване на начисляването
- `month_writeoff_accounting` - Месец на отписване от счетоводен план
- `month_writeoff_tax` - Месец на отписване от данъчен план
- `depreciation_months_current_year` - Брой месеци с начислена амортизация през годината

**За SAF-T ValuationSAP (Счетоводна оценка):**
- `acquisition_cost_begin_year` - Придобивна стойност в началото на годината
- `book_value_begin_year` - Балансова стойност в началото на годината
- `accumulated_depreciation_begin_year` - Натрупана амортизация в началото на годината

**Допълнителни полета:**
- `startup_date` - Дата на въвеждане в експлоатация
- `purchase_order_date` - Дата на поръчка

## Използване

### 1. Увеличаване на стойността на актив

```elixir
# Зареждаме актив
asset = FixedAssets.get_asset!(tenant_id, asset_id)

# Увеличаваме стойността с 5000 лв
{:ok, {updated_asset, transaction}} =
  FixedAssets.increase_asset_value(asset, %{
    amount: Decimal.new("5000.00"),
    transaction_date: ~D[2025-03-15],
    description: "Подобрение на активa - нова функционалност",
    regenerate_schedule: true  # Опционално - преизчислява амортизацията
  })
```

**Какво прави тази функция:**
1. Актуализира `acquisition_cost` на актива
2. Записва `month_value_change` за SAF-T отчитането
3. Създава транзакция тип "20" (IMP - Improvement)
4. Опционално - изтрива планираните амортизации и генерира нови

### 2. Записване на транзакции за амортизация

При постване на амортизация автоматично се записва транзакция:

```elixir
# Постване на амортизация
{:ok, schedule} = FixedAssets.post_depreciation(depreciation_schedule)

# Автоматично създава транзакция тип "30" (DEP)
{:ok, transaction} = FixedAssets.record_depreciation_transaction(schedule)
```

### 3. Подготовка на данни в началото на годината

**ВАЖНО:** В началото на всяка година трябва да се изпълни:

```elixir
# Запазва началните стойности за всички активи
FixedAssets.prepare_year_beginning_values(tenant_id, 2025)
```

Тази функция записва:
- Началната придобивна стойност
- Началната балансова стойност
- Началната натрупана амортизация
- Нулира броя месеци с амортизация за текущата година

### 4. Генериране на SAF-T годишен файл

```elixir
# Генерира SAF-T XML файл за 2025 година
SaftExport.generate_annual(tenant_id, 2025, "/tmp/saft_annual_2025.xml")
```

**Съдържание на файла:**
1. **MasterFilesAnnual/Assets** - Списък с всички активи с:
   - ValuationSAP (счетоводна оценка)
   - ValuationDAP (данъчен амортизационен план)

2. **SourceDocumentsAnnual/AssetTransactions** - Всички транзакции с активи за годината

## Workflow при работа с ДМА

### При придобиване на нов актив:

```elixir
# 1. Създаване на актив
{:ok, asset} = FixedAssets.create_asset_with_schedule(%{
  tenant_id: 1,
  code: "ДА000100",
  name: "Лек автомобил VW Golf",
  category: "Транспортни средства",
  tax_category: "V",  # Автомобили - 25% годишна норма
  acquisition_date: ~D[2025-01-15],
  acquisition_cost: Decimal.new("25000.00"),
  startup_date: ~D[2025-01-20],
  purchase_order_date: ~D[2025-01-10],
  useful_life_months: 48,
  depreciation_method: "straight_line",
  supplier_id: supplier.id,
  invoice_number: "INV-2025-001",
  invoice_date: ~D[2025-01-15]
})

# 2. Записваме транзакция за придобиване
{:ok, acq_transaction} = FixedAssets.record_acquisition_transaction(asset)
```

### При увеличаване на стойността:

```elixir
# Подобрение на актив през март 2025
{:ok, {updated_asset, imp_transaction}} =
  FixedAssets.increase_asset_value(asset, %{
    amount: Decimal.new("3000.00"),
    transaction_date: ~D[2025-03-10],
    description: "Подобрение - монтиране на ГБО система",
    regenerate_schedule: true
  })
```

### При извеждане от употреба:

```elixir
# Извеждане поради продажба
{:ok, disposed_asset} = FixedAssets.dispose_asset(asset, %{
  disposal_date: ~D[2025-12-15],
  disposal_reason: "Продажба",
  disposal_value: Decimal.new("15000.00")
})

# Записваме транзакция за продажба
{:ok, dsp_transaction} = FixedAssets.record_disposal_transaction(disposed_asset, "50")

# За брак използваме код "60"
{:ok, scr_transaction} = FixedAssets.record_disposal_transaction(disposed_asset, "60")
```

## Годишна процедура за SAF-T

**1 януари всяка година:**

```elixir
# Подготовка на началните стойности
FixedAssets.prepare_year_beginning_values(tenant_id, 2025)
```

**Края на годината - генериране на файла:**

```elixir
# Генериране на SAF-T файл
SaftExport.generate_annual(tenant_id, 2025, "/path/to/saft_annual_2025.xml")
```

## Структура на SAF-T XML

### Assets секция (пример):

```xml
<nsSAFT:Asset>
  <nsSAFT:AssetID>ДА000100</nsSAFT:AssetID>
  <nsSAFT:AccountID>206</nsSAFT:AccountID>
  <nsSAFT:Description>Лек автомобил VW Golf</nsSAFT:Description>
  <nsSAFT:DateOfAcquisition>2025-01-15</nsSAFT:DateOfAcquisition>
  <nsSAFT:StartUpDate>2025-01-20</nsSAFT:StartUpDate>
  <nsSAFT:Valuations>
    <nsSAFT:ValuationSAP>
      <!-- Счетоводна оценка -->
      <nsSAFT:AcquisitionAndProductionCostsBegin>25000.00</nsSAFT:AcquisitionAndProductionCostsBegin>
      <nsSAFT:AcquisitionAndProductionCostsEnd>28000.00</nsSAFT:AcquisitionAndProductionCostsEnd>
      <nsSAFT:BookValueBegin>25000.00</nsSAFT:BookValueBegin>
      <nsSAFT:BookValueEnd>22000.00</nsSAFT:BookValueEnd>
      ...
    </nsSAFT:ValuationSAP>
    <nsSAFT:ValuationDAP>
      <!-- Данъчен амортизационен план -->
      <nsSAFT:MonthChangeAssetValue>3</nsSAFT:MonthChangeAssetValue>
      <nsSAFT:NumberMonthsDepreciationDuring>12</nsSAFT:NumberMonthsDepreciationDuring>
      ...
    </nsSAFT:ValuationDAP>
  </nsSAFT:Valuations>
</nsSAFT:Asset>
```

### AssetTransactions секция (пример):

```xml
<nsSAFT:AssetTransaction>
  <nsSAFT:AssetTransactionID>42</nsSAFT:AssetTransactionID>
  <nsSAFT:AssetID>ДА000100</nsSAFT:AssetID>
  <nsSAFT:AssetTransactionType>20</nsSAFT:AssetTransactionType>
  <nsSAFT:Description>Подобрение - монтиране на ГБО система</nsSAFT:Description>
  <nsSAFT:AssetTransactionDate>2025-03-10</nsSAFT:AssetTransactionDate>
  <nsSAFT:AssetTransactionValuations>
    <nsSAFT:AssetTransactionValuation>
      <nsSAFT:AcquisitionAndProductionCostsOnTransaction>3000.00</nsSAFT:AcquisitionAndProductionCostsOnTransaction>
      <nsSAFT:BookValueOnTransaction>25500.00</nsSAFT:BookValueOnTransaction>
      <nsSAFT:AssetTransactionAmount>3000.00</nsSAFT:AssetTransactionAmount>
    </nsSAFT:AssetTransactionValuation>
  </nsSAFT:AssetTransactionValuations>
</nsSAFT:AssetTransaction>
```

## Важни бележки

1. **Увеличаване на стойността:**
   - Според счетоводната практика описана в документацията:
   - Първо се начисляват амортизации до месеца на промяна
   - След това се увеличава стойността
   - Данъчната амортизация се преизчислява спрямо новата стойност

2. **Месец на промяна:**
   - Автоматично се записва в полето `month_value_change`
   - Използва се за ValuationDAP в SAF-T файла

3. **Транзакции:**
   - Всички транзакции се записват автоматично
   - За амортизация - при постване
   - За придобиване - ръчно след създаване на актив
   - За извеждане - ръчно след dispose_asset

4. **Начални стойности:**
   - ЗАДЪЛЖИТЕЛНО да се изпълни `prepare_year_beginning_values` в началото на годината
   - Иначе SAF-T файлът няма да съдържа коректни данни

## Примерен сценарий

```elixir
# 1 януари 2025 - Подготовка за новата година
FixedAssets.prepare_year_beginning_values(tenant_id, 2025)

# 15 януари 2025 - Придобиване на актив
{:ok, asset} = FixedAssets.create_asset_with_schedule(%{...})
FixedAssets.record_acquisition_transaction(asset)

# 31 януари 2025 - Месечна амортизация
{:ok, schedule} = FixedAssets.post_depreciation(schedule)

# 10 март 2025 - Увеличаване на стойността
FixedAssets.increase_asset_value(asset, %{
  amount: Decimal.new("3000.00"),
  transaction_date: ~D[2025-03-10],
  regenerate_schedule: true
})

# 31 март 2025 - Месечна амортизация с нова стойност
{:ok, schedule} = FixedAssets.post_depreciation(schedule)

# ... през цялата година

# 31 декември 2025 - Генериране на SAF-T годишен файл
SaftExport.generate_annual(tenant_id, 2025, "/tmp/saft_2025.xml")
```

## Тестване

За тестване на функционалността може да се използва:

```elixir
# Влизаме в IEx конзолата
iex -S mix

# Създаваме тестов актив и увеличаваме стойността му
alias CyberCore.Accounting.FixedAssets
alias Decimal

# ... създаване на актив ...

# Увеличаване на стойността
{:ok, {asset, tx}} = FixedAssets.increase_asset_value(asset, %{
  amount: Decimal.new("1000.00"),
  description: "Тестово подобрение"
})

# Проверка на транзакциите
transactions = FixedAssets.list_asset_transactions(asset.id)
```
