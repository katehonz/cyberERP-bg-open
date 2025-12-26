# Скрипт за създаване на тестови дълготрайни активи
# Изпълни с: mix run test_fixed_assets.exs

alias CyberCore.Accounting.FixedAssets
alias CyberCore.Repo

IO.puts("🔧 Създаване на тестови дълготрайни активи...")

tenant_id = 1

# Актив 1: Лаптоп
{:ok, laptop} = FixedAssets.create_asset(%{
  tenant_id: tenant_id,
  code: "DMA-001",
  name: "Лаптоп Dell Latitude 5420",
  category: "computer",
  inventory_number: "INV-2025-001",
  serial_number: "DLAT5420-12345",
  location: "Офис София, ет. 3",
  responsible_person: "Иван Иванов",
  tax_category: "IV",
  tax_depreciation_rate: Decimal.new("0.50"),
  accounting_depreciation_rate: Decimal.new("0.50"),
  acquisition_date: ~D[2025-01-15],
  acquisition_cost: Decimal.new("2400.00"),
  salvage_value: Decimal.new("0"),
  useful_life_months: 36,
  depreciation_method: "straight_line",
  status: "active",
  notes: "Лаптоп за офис работа"
})

IO.puts("✅ Създаден: #{laptop.name}")

# Актив 2: Автомобил
{:ok, car} = FixedAssets.create_asset(%{
  tenant_id: tenant_id,
  code: "DMA-002",
  name: "Автомобил Toyota Corolla",
  category: "vehicle",
  inventory_number: "INV-2025-002",
  serial_number: "TC2024-67890",
  location: "Паркинг",
  responsible_person: "Петър Петров",
  tax_category: "V",
  tax_depreciation_rate: Decimal.new("0.25"),
  accounting_depreciation_rate: Decimal.new("0.25"),
  acquisition_date: ~D[2024-11-01],
  acquisition_cost: Decimal.new("45000.00"),
  salvage_value: Decimal.new("5000.00"),
  useful_life_months: 60,
  depreciation_method: "straight_line",
  status: "active",
  notes: "Служебен автомобил"
})

IO.puts("✅ Създаден: #{car.name}")

# Актив 3: Принтер
{:ok, printer} = FixedAssets.create_asset(%{
  tenant_id: tenant_id,
  code: "DMA-003",
  name: "Принтер HP LaserJet Pro",
  category: "office",
  inventory_number: "INV-2025-003",
  tax_category: "IV",
  tax_depreciation_rate: Decimal.new("0.50"),
  accounting_depreciation_rate: Decimal.new("0.50"),
  acquisition_date: ~D[2025-02-01],
  acquisition_cost: Decimal.new("1200.00"),
  salvage_value: Decimal.new("0"),
  useful_life_months: 36,
  depreciation_method: "straight_line",
  status: "active"
})

IO.puts("✅ Създаден: #{printer.name}")

# Генериране на графици за амортизация
IO.puts("\n📅 Генериране на графици за амортизация...")

case FixedAssets.generate_depreciation_schedule(laptop) do
  {:ok, schedules} ->
    IO.puts("✅ Генериран график за #{laptop.name}: #{length(schedules)} месеца")
  {:error, reason} ->
    IO.puts("❌ Грешка при генериране на график: #{inspect(reason)}")
end

case FixedAssets.generate_depreciation_schedule(car) do
  {:ok, schedules} ->
    IO.puts("✅ Генериран график за #{car.name}: #{length(schedules)} месеца")
  {:error, reason} ->
    IO.puts("❌ Грешка при генериране на график: #{inspect(reason)}")
end

case FixedAssets.generate_depreciation_schedule(printer) do
  {:ok, schedules} ->
    IO.puts("✅ Генериран график за #{printer.name}: #{length(schedules)} месеца")
  {:error, reason} ->
    IO.puts("❌ Грешка при генериране на график: #{inspect(reason)}")
end

IO.puts("\n🎉 Готово! Отвори http://localhost:4000/fixed-assets")
IO.puts("📊 Създадени #{FixedAssets.list_assets(tenant_id) |> length()} актива")

# Покажи статистика
stats = FixedAssets.get_assets_statistics(tenant_id)
IO.puts("\n📈 Статистика:")
IO.puts("   Общо активи: #{stats.total_count}")
IO.puts("   Активни: #{stats.active_count}")
IO.puts("   Обща стойност: #{stats.total_acquisition_cost} лв")
IO.puts("   Балансова стойност: #{stats.total_book_value} лв")
