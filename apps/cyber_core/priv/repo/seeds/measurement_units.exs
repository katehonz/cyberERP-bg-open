# Script за зареждане на стандартни мерни единици
# Стартира се с: mix run priv/repo/seeds/measurement_units.exs

alias CyberCore.Repo
alias CyberCore.Accounts.Tenant
alias CyberCore.Inventory.MeasurementUnit

# Вземане на всички тенанти
tenants = Repo.all(Tenant)

# Стандартни мерни единици според SAF-T и Intrastat
standard_units = [
  # Маса
  %{code: "kg", name_bg: "Килограм", name_en: "Kilogram", symbol: "kg", is_base: true},
  %{code: "g", name_bg: "Грам", name_en: "Gram", symbol: "g", is_base: false},
  %{code: "t", name_bg: "Тон", name_en: "Ton", symbol: "t", is_base: false},

  # Обем
  %{code: "l", name_bg: "Литър", name_en: "Liter", symbol: "l", is_base: true},
  %{code: "ml", name_bg: "Милилитър", name_en: "Milliliter", symbol: "ml", is_base: false},
  %{code: "hl", name_bg: "Хектолитър", name_en: "Hectoliter", symbol: "hl", is_base: false},

  # Дължина
  %{code: "m", name_bg: "Метър", name_en: "Meter", symbol: "m", is_base: true},
  %{code: "cm", name_bg: "Сантиметър", name_en: "Centimeter", symbol: "cm", is_base: false},
  %{code: "mm", name_bg: "Милиметър", name_en: "Millimeter", symbol: "mm", is_base: false},
  %{code: "km", name_bg: "Километър", name_en: "Kilometer", symbol: "km", is_base: false},

  # Площ
  %{code: "m2", name_bg: "Квадратен метър", name_en: "Square meter", symbol: "m²", is_base: true},
  %{code: "cm2", name_bg: "Квадратен сантиметър", name_en: "Square centimeter", symbol: "cm²", is_base: false},
  %{code: "ha", name_bg: "Хектар", name_en: "Hectare", symbol: "ha", is_base: false},

  # Обем (кубичен)
  %{code: "m3", name_bg: "Кубичен метър", name_en: "Cubic meter", symbol: "m³", is_base: true},
  %{code: "cm3", name_bg: "Кубичен сантиметър", name_en: "Cubic centimeter", symbol: "cm³", is_base: false},

  # Брой
  %{code: "p/st", name_bg: "Брой", name_en: "Piece", symbol: "бр.", is_base: true},
  %{code: "pair", name_bg: "Двойка", name_en: "Pair", symbol: "двойка", is_base: false},
  %{code: "set", name_bg: "Комплект", name_en: "Set", symbol: "компл.", is_base: false},
  %{code: "dozen", name_bg: "Дузина", name_en: "Dozen", symbol: "дуз.", is_base: false},

  # Опаковки
  %{code: "pack", name_bg: "Пакет", name_en: "Package", symbol: "пак.", is_base: false},
  %{code: "box", name_bg: "Кутия", name_en: "Box", symbol: "кут.", is_base: false},
  %{code: "pallet", name_bg: "Палет", name_en: "Pallet", symbol: "палет", is_base: false},
  %{code: "bag", name_bg: "Торба", name_en: "Bag", symbol: "торба", is_base: false},
  %{code: "bottle", name_bg: "Бутилка", name_en: "Bottle", symbol: "бут.", is_base: false},
  %{code: "can", name_bg: "Кен", name_en: "Can", symbol: "кен", is_base: false},

  # Енергия
  %{code: "kwh", name_bg: "Киловатчас", name_en: "Kilowatt-hour", symbol: "kWh", is_base: true},
  %{code: "mwh", name_bg: "Мегаватчас", name_en: "Megawatt-hour", symbol: "MWh", is_base: false},

  # Други
  %{code: "hour", name_bg: "Час", name_en: "Hour", symbol: "ч", is_base: true},
  %{code: "day", name_bg: "Ден", name_en: "Day", symbol: "дни", is_base: false},
  %{code: "month", name_bg: "Месец", name_en: "Month", symbol: "мес.", is_base: false}
]

# Създаване на мерни единици за всеки тенант
Enum.each(tenants, fn tenant ->
  IO.puts("Създаване на стандартни мерни единици за тенант: #{tenant.name}")

  Enum.each(standard_units, fn unit_data ->
    case Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: unit_data.code) do
      nil ->
        unit_data
        |> Map.put(:tenant_id, tenant.id)
        |> then(&MeasurementUnit.changeset(%MeasurementUnit{}, &1))
        |> Repo.insert()
        |> case do
          {:ok, _unit} ->
            IO.puts("  ✓ Създадена мерна единица: #{unit_data.code} - #{unit_data.name_bg}")

          {:error, changeset} ->
            IO.puts("  ✗ Грешка при създаване на #{unit_data.code}: #{inspect(changeset.errors)}")
        end

      _existing ->
        IO.puts("  - Мерна единица #{unit_data.code} вече съществува")
    end
  end)
end)

IO.puts("\n✓ Seed завършен успешно!")
