# Бърза настройка на номенклатурите

Следвайте тези стъпки за настройка на номенклатурите в системата:

## 1. Изпълнение на миграциите

```bash
mix ecto.migrate
```

Това ще създаде следните таблици:
- `cn_nomenclatures` - Комбинирана номенклатура КН8
- `measurement_units` - Мерни единици
- `product_units` - Връзка продукт-мерна единица
- Добавя `cn_code_id` към `products`

## 2. Зареждане на стандартни мерни единици

```bash
mix run apps/cyber_core/priv/repo/seeds/measurement_units.exs
```

Това ще създаде ~30 стандартни мерни единици за всички тенанти:
- kg, g, t (маса)
- l, ml, hl (обем)
- m, cm, mm (дължина)
- m², m³ (площ, обем)
- бр., двойка, комплект (брой)
- кутия, палет, торба (опаковки)
- и други...

## 3. Импорт на КН номенклатура 2025

```bash
mix run apps/cyber_core/priv/repo/seeds/cn_nomenclature_2025.exs
```

Това ще импортира ~15,000 записа от `FILE/INTRASTAT/CN_2025_NAP (1.csv`

**Забележка:** Импортът може да отнеме 2-3 минути.

## 4. (Опционално) Създаване на примерни продукти

```bash
mix run apps/cyber_core/priv/repo/seeds/example_products.exs
```

Това ще създаде 3 примерни продукта с мулти мерни единици:
- Минерална вода (литър, бутилка, кутия)
- Прясно мляко (литър, кутия, палет)
- Кафе (kg, g, кутия)

## Проверка на импорта

### В IEx консола

```bash
iex -S mix
```

```elixir
alias CyberCore.Repo
alias CyberCore.Inventory.{CnNomenclature, MeasurementUnit, Product}

# Брой КН кодове
Repo.aggregate(CnNomenclature, :count, :id)

# Брой мерни единици
Repo.aggregate(MeasurementUnit, :count, :id)

# Пример КН код
Repo.get_by(CnNomenclature, code: "01012100", year: 2025)

# Всички продукти
Repo.all(Product) |> Repo.preload([:cn_code, :product_units])
```

### В браузър

```
http://localhost:4000/products
```

## Следващи стъпки

След настройката можете да:

1. **Създавате продукти** с връзка към КН номенклатура
2. **Добавяте мулти мерни единици** към продукти
3. **Генерирате SAF-T експорт** с коректни номенклатури
4. **Подготвяте Intrastat декларации** с КН кодове

## Допълнителна документация

- [NOMENCLATURES.md](./NOMENCLATURES.md) - Общ преглед
- [apps/cyber_core/lib/cyber_core/inventory/README.md](./apps/cyber_core/lib/cyber_core/inventory/README.md) - Техническа документация
- [FILE/SAFT_BG/](./FILE/SAFT_BG/) - SAF-T спецификация
- [FILE/INTRASTAT/](./FILE/INTRASTAT/) - Intrastat ресурси

## Проблеми

### CSV библиотека не е налична

```bash
mix deps.get
```

### Миграциите са вече изпълнени

```bash
mix ecto.rollback --step 4  # Връща 4 миграции назад
mix ecto.migrate            # Изпълнява отново
```

### Данните вече са заредени

Seed скриптовете проверяват за дублиращи се записи и ги прескачат.
За пълно презареждане:

```bash
mix ecto.reset  # ВНИМАНИЕ: Изтрива ВСИЧКИ данни!
```
