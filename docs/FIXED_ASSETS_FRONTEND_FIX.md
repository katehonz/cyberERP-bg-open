# Fixed Assets Frontend - Поправки

## Проблем

При отваряне на `/fixed-assets` се получаваше грешка:

```
UndefinedFunctionError: function Number.Currency.number_to_currency/2 is undefined
(module Number.Currency is not available)
```

## Причина

Използвана беше функция `Number.Currency.number_to_currency/2` от библиотеката `number`, която не е инсталирана в проекта.

## Решение

Създадена беше собствена функция за форматиране на валути в `format_currency/1`, която:

1. Работи с `Decimal` типове
2. Закръгля до 2 десетични знака
3. Добавя разделители за хилядите (space)
4. Форматира валутата в български формат с "лв."

### Имплементация

```elixir
defp format_currency(amount) when is_nil(amount), do: "0.00 лв."
defp format_currency(%Decimal{} = amount) do
  amount
  |> Decimal.round(2)
  |> Decimal.to_string()
  |> format_currency_string()
end
defp format_currency(amount) when is_number(amount) do
  amount
  |> Decimal.from_float()
  |> format_currency()
end

defp format_currency_string(str) do
  [int_part, dec_part] = String.split(str <> ".00", ".") |> Enum.take(2)

  formatted_int = int_part
  |> String.reverse()
  |> String.graphemes()
  |> Enum.chunk_every(3)
  |> Enum.join(" ")
  |> String.reverse()

  "#{formatted_int}.#{String.pad_trailing(dec_part, 2, "0")} лв."
end
```

### Примери

```elixir
format_currency(Decimal.new("1234.56"))
# => "1 234.56 лв."

format_currency(Decimal.new("1000000"))
# => "1 000 000.00 лв."

format_currency(nil)
# => "0.00 лв."
```

## Променени файлове

1. `apps/cyber_web/lib/cyber_web/live/fixed_asset_live/index.ex`
   - Добавена функция `format_currency/1`
   - Заменени всички `Number.Currency.number_to_currency/2` с `format_currency/1`

2. `apps/cyber_web/lib/cyber_web/live/fixed_asset_live/schedule_component.ex`
   - Добавена функция `format_currency/1`
   - Заменени всички `Number.Currency.number_to_currency/2` с `format_currency/1`

## Резултат

✅ Страницата `/fixed-assets` се зарежда без грешки
✅ Валутите се показват коректно във формат "1 234.56 лв."
✅ Всички статистически карти работят
✅ Таблицата с активи се показва правилно

## Тестване

За да тествате:

1. Отворете браузър на `http://localhost:4000/fixed-assets`
2. Проверете:
   - Статистическите карти се показват коректно
   - Сумите са форматирани като "X XXX.XX лв."
   - Няма JavaScript грешки в конзолата

## Бъдещи подобрения

Ако се реши да се използва библиотека за форматиране на числа, може да се добави:

```elixir
# В mix.exs
{:number, "~> 1.0"}
```

Тогава може да се върне към използването на `Number.Currency.number_to_currency/2`.
