# Seed скрипт за дълготрайни активи
#
# Създава демонстрационни данни за:
# - Различни категории активи
# - Амортизационни графици
# - Транзакции
#
# Използване:
#   mix run priv/repo/seeds/fixed_assets_seed.exs

alias CyberCore.Repo
alias CyberCore.Accounts
alias CyberCore.Settings
alias CyberCore.Accounting
alias CyberCore.Accounting.FixedAssets

# Намираме tenant
tenant = Repo.get_by!(Accounts.Tenant, name: "Тестова фирма ООД")
IO.puts("🏢 Tenant: #{tenant.name} (ID: #{tenant.id})")

# Намираме необходимите счетоводни сметки
account_203 = Repo.get_by(Accounting.Account, tenant_id: tenant.id, code: "203")
account_283 = Repo.get_by(Accounting.Account, tenant_id: tenant.id, code: "283")
account_604 = Repo.get_by(Accounting.Account, tenant_id: tenant.id, code: "604")
account_501 = Repo.get_by(Accounting.Account, tenant_id: tenant.id, code: "501")

# Ако няма сметки, създаваме ги
account_203 = account_203 || Repo.insert!(%Accounting.Account{
  tenant_id: tenant.id,
  code: "203",
  name: "Компютърна техника",
  account_type: "asset",
  parent_code: "20"
})

account_283 = account_283 || Repo.insert!(%Accounting.Account{
  tenant_id: tenant.id,
  code: "283",
  name: "Амортизация на компютърна техника",
  account_type: "asset",
  parent_code: "28"
})

account_604 = account_604 || Repo.insert!(%Accounting.Account{
  tenant_id: tenant.id,
  code: "604",
  name: "Амортизации",
  account_type: "expense",
  parent_code: "60"
})

account_501 = account_501 || Repo.insert!(%Accounting.Account{
  tenant_id: tenant.id,
  code: "501",
  name: "Разплащателна сметка BGN",
  account_type: "bank",
  parent_code: "50"
})

IO.puts("✅ Счетоводни сметки готови")

# Намираме или създаваме доставчик
supplier = case Repo.get_by(Accounting.Contact, tenant_id: tenant.id, name: "TechnoPlus ЕООД") do
  nil ->
    Repo.insert!(%Accounting.Contact{
      tenant_id: tenant.id,
      name: "TechnoPlus ЕООД",
      vat_number: "BG123456789",
      contact_type: "supplier",
      email: "info@technoplus.bg",
      phone: "+359 2 123 4567",
      address: "София, ул. Технологична 15"
    })
  contact -> contact
end

IO.puts("✅ Доставчик: #{supplier.name}")

# Дефиниция на примерни активи
sample_assets = [
  %{
    code: "DMA-2025-001",
    name: "Лаптоп Dell Latitude 5420",
    category: "Компютърна техника",
    tax_category: "III",  # 30% годишна норма
    acquisition_date: ~D[2025-01-15],
    acquisition_cost: Decimal.new("2400.00"),
    startup_date: ~D[2025-01-20],
    purchase_order_date: ~D[2025-01-10],
    inventory_number: "INV-2025-001",
    serial_number: "DELL-SN-789456123",
    location: "Офис София, етаж 2",
    responsible_person: "Иван Петров",
    useful_life_months: 36,
    depreciation_method: "straight_line",
    salvage_value: Decimal.new("0"),
    supplier_id: supplier.id,
    accounting_account_id: account_203.id,
    expense_account_id: account_604.id,
    accumulated_depreciation_account_id: account_283.id,
    invoice_number: "INV-2025-0015",
    invoice_date: ~D[2025-01-10],
    notes: "Служебен лаптоп за счетоводен отдел"
  },
  %{
    code: "DMA-2025-002",
    name: "Принтер HP LaserJet Pro",
    category: "Офис оборудване",
    tax_category: "IV",  # 25% годишна норма
    acquisition_date: ~D[2025-02-01],
    acquisition_cost: Decimal.new("890.00"),
    startup_date: ~D[2025-02-05],
    inventory_number: "INV-2025-002",
    serial_number: "HP-LJ-456789",
    location: "Офис София, етаж 1",
    responsible_person: "Мария Георгиева",
    useful_life_months: 48,
    depreciation_method: "straight_line",
    salvage_value: Decimal.new("50.00"),
    supplier_id: supplier.id,
    accounting_account_id: account_203.id,
    expense_account_id: account_604.id,
    accumulated_depreciation_account_id: account_283.id,
    invoice_number: "INV-2025-0042",
    invoice_date: ~D[2025-01-28]
  },
  %{
    code: "DMA-2024-015",
    name: "Автомобил VW Golf 8",
    category: "Транспортни средства",
    tax_category: "V",  # 25% годишна норма (леки автомобили)
    acquisition_date: ~D[2024-03-10],
    acquisition_cost: Decimal.new("45000.00"),
    startup_date: ~D[2024-03-15],
    purchase_order_date: ~D[2024-02-20],
    inventory_number: "INV-2024-008",
    serial_number: "VIN-WVW123456789",
    location: "Паркинг София",
    responsible_person: "Георги Димитров",
    useful_life_months: 60,
    depreciation_method: "straight_line",
    salvage_value: Decimal.new("5000.00"),
    supplier_id: supplier.id,
    accounting_account_id: account_203.id,
    expense_account_id: account_604.id,
    accumulated_depreciation_account_id: account_283.id,
    invoice_number: "INV-2024-0125",
    invoice_date: ~D[2024-03-05],
    notes: "Служебен автомобил"
  },
  %{
    code: "DMA-2024-022",
    name: "Сървър HP ProLiant DL380",
    category: "Компютърна техника",
    tax_category: "III",  # 30% годишна норма
    acquisition_date: ~D[2024-06-15],
    acquisition_cost: Decimal.new("8500.00"),
    startup_date: ~D[2024-06-20],
    inventory_number: "INV-2024-022",
    serial_number: "HP-SERVER-987654",
    location: "Сървърна зала",
    responsible_person: "Петър Стоянов",
    useful_life_months: 60,
    depreciation_method: "straight_line",
    salvage_value: Decimal.new("500.00"),
    supplier_id: supplier.id,
    accounting_account_id: account_203.id,
    expense_account_id: account_604.id,
    accumulated_depreciation_account_id: account_283.id,
    invoice_number: "INV-2024-0298",
    invoice_date: ~D[2024-06-10],
    notes: "Production сървър"
  },
  %{
    code: "DMA-2023-005",
    name: "Климатик Daikin 12000 BTU",
    category: "Офис оборудване",
    tax_category: "IV",  # 25% годишна норма
    acquisition_date: ~D[2023-05-20],
    acquisition_cost: Decimal.new("1850.00"),
    startup_date: ~D[2023-05-25],
    inventory_number: "INV-2023-005",
    serial_number: "DAIKIN-AC-456123",
    location: "Офис София, конферентна зала",
    responsible_person: "Мария Георгиева",
    useful_life_months: 84,
    depreciation_method: "straight_line",
    salvage_value: Decimal.new("150.00"),
    supplier_id: supplier.id,
    accounting_account_id: account_203.id,
    expense_account_id: account_604.id,
    accumulated_depreciation_account_id: account_283.id,
    invoice_number: "INV-2023-0089",
    invoice_date: ~D[2023-05-15],
    notes: "Климатична инсталация"
  }
]

IO.puts("\n📦 Създаване на активи...")

created_assets = Enum.map(sample_assets, fn asset_attrs ->
  # Проверяваме дали активът вече съществува
  existing = Repo.get_by(Accounting.Asset, tenant_id: tenant.id, code: asset_attrs.code)

  if existing do
    IO.puts("  ⏭️  #{asset_attrs.code} - #{asset_attrs.name} (вече съществува)")
    existing
  else
    case FixedAssets.create_asset_with_schedule(Map.put(asset_attrs, :tenant_id, tenant.id)) do
      {:ok, asset} ->
        IO.puts("  ✅ #{asset.code} - #{asset.name}")

        # Създаваме транзакция за придобиване
        FixedAssets.record_acquisition_transaction(asset)

        asset
      {:error, changeset} ->
        IO.puts("  ❌ Грешка при създаване на #{asset_attrs.code}:")
        IO.inspect(changeset.errors)
        nil
    end
  end
end)
|> Enum.reject(&is_nil/1)

IO.puts("\n✅ Създадени #{length(created_assets)} активa")

# Подготовка на началните стойности за 2025
IO.puts("\n📅 Подготовка на началните стойности за 2025...")
{:ok, count} = FixedAssets.prepare_year_beginning_values(tenant.id, 2025)
IO.puts("✅ Подготвени #{count} активa")

# Постваме амортизация за изминалите месеци на 2024
IO.puts("\n💰 Постване на амортизация за 2024...")

old_assets = Enum.filter(created_assets, fn asset ->
  asset.acquisition_date.year == 2024 || asset.acquisition_date.year == 2023
end)

months_2024 = Enum.map(1..12, fn month ->
  Date.new!(2024, month, 1)
end)

total_posted = Enum.reduce(months_2024, 0, fn period_date, acc ->
  case FixedAssets.post_period_depreciation(tenant.id, period_date) do
    {:ok, count} when count > 0 ->
      IO.puts("  ✅ #{Calendar.strftime(period_date, "%B %Y")}: #{count} записа")
      acc + count
    {:ok, 0} ->
      acc
    {:error, _} ->
      IO.puts("  ⏭️  #{Calendar.strftime(period_date, "%B %Y")}: пропуснат")
      acc
  end
end)

IO.puts("✅ Постнати общо #{total_posted} амортизационни записа")

# Примерно увеличаване на стойност
IO.puts("\n📈 Демонстрация на увеличаване на стойност...")

laptop = Enum.find(created_assets, fn a -> a.code == "DMA-2025-001" end)

if laptop do
  case FixedAssets.increase_asset_value_with_accounting(laptop, %{
    amount: Decimal.new("500.00"),
    transaction_date: ~D[2025-03-15],
    description: "Добавена RAM памет 32GB",
    regenerate_schedule: true
  }, account_501.id) do
    {:ok, {updated_asset, transaction, _journal_entry}} ->
      IO.puts("  ✅ Увеличена стойността на #{updated_asset.name}")
      IO.puts("     Нова стойност: #{updated_asset.acquisition_cost} лв.")
      IO.puts("     Транзакция: #{transaction.transaction_type_name}")
    {:error, reason} ->
      IO.puts("  ❌ Грешка: #{inspect(reason)}")
  end
end

# Статистика
IO.puts("\n📊 Статистика:")
stats = FixedAssets.get_assets_statistics(tenant.id)
IO.puts("  Общо активи: #{stats.total_count}")
IO.puts("  Активни: #{stats.active_count}")
IO.puts("  Обща придобивна стойност: #{stats.total_acquisition_cost} лв.")
IO.puts("  Натрупана амортизация: #{stats.total_accumulated_depreciation} лв.")
IO.puts("  Балансова стойност: #{stats.total_book_value} лв.")

IO.puts("\n🎉 Seed данните са заредени успешно!")
