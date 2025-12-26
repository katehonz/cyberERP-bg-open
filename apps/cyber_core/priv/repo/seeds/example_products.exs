# Примерен seed script за създаване на продукти с мулти мерни единици
# Стартира се с: mix run priv/repo/seeds/example_products.exs

alias CyberCore.Repo
alias CyberCore.Inventory.{Product, MeasurementUnit, ProductUnit, CnNomenclature}
alias CyberCore.Accounts.Tenant

IO.puts("\n=== Създаване на примерни продукти с мулти мерни единици ===\n")

# Взимане на първия тенант
tenant = Repo.all(Tenant) |> List.first()

if is_nil(tenant) do
  IO.puts("✗ Няма създадени тенанти. Моля, създайте тенант първо.")
  exit(:normal)
end

IO.puts("Тенант: #{tenant.name}")

# Проверка дали има заредени мерни единици
unit_count = Repo.aggregate(MeasurementUnit, :count, :id)

if unit_count == 0 do
  IO.puts("\n✗ Няма заредени мерни единици.")
  IO.puts("Моля, стартирайте първо: mix run priv/repo/seeds/measurement_units.exs")
  exit(:normal)
end

IO.puts("Заредени мерни единици: #{unit_count}")

# Проверка дали има заредени КН кодове
cn_count = Repo.aggregate(CnNomenclature, :count, :id)

if cn_count == 0 do
  IO.puts("\n⚠ Няма заредени КН кодове.")
  IO.puts("За пълна функционалност, стартирайте: mix run priv/repo/seeds/cn_nomenclature_2025.exs")
end

# Взимане на мерни единици
unit_l = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "l")
unit_ml = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "ml")
unit_bottle = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "bottle")
unit_box = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "box")
unit_pallet = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "pallet")
unit_kg = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "kg")
unit_g = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "g")
unit_piece = Repo.get_by(MeasurementUnit, tenant_id: tenant.id, code: "p/st")

IO.puts("\n--- Продукт 1: Минерална вода ---")

# Проверка дали продуктът вече съществува
case Repo.get_by(Product, tenant_id: tenant.id, sku: "WATER-001") do
  nil ->
    {:ok, water} =
      %Product{}
      |> Product.changeset(%{
        tenant_id: tenant.id,
        name: "Минерална вода Девин 1.5л",
        sku: "WATER-001",
        category: "goods",
        price: Decimal.new("1.20"),
        cost: Decimal.new("0.80")
      })
      |> Repo.insert()

    IO.puts("✓ Създаден продукт: #{water.name}")

    # Основна мерна единица - литър
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: water.id,
      measurement_unit_id: unit_l.id,
      conversion_factor: Decimal.new("1.5"),
      is_primary: true,
      barcode: "3800010010015"
    })
    |> Repo.insert()

    IO.puts("  + Основна единица: 1.5 литра (баркод: 3800010010015)")

    # Допълнителна единица - бутилка
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: water.id,
      measurement_unit_id: unit_bottle.id,
      conversion_factor: Decimal.new("1.5"),
      is_primary: false
    })
    |> Repo.insert()

    IO.puts("  + Допълнителна: 1 бутилка = 1.5л")

    # Кутия 6 бутилки
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: water.id,
      measurement_unit_id: unit_box.id,
      conversion_factor: Decimal.new("9"),
      is_primary: false,
      barcode: "3800010010022"
    })
    |> Repo.insert()

    IO.puts("  + Кутия: 6 бутилки = 9л (баркод: 3800010010022)")

  existing ->
    IO.puts("- Продуктът вече съществува: #{existing.name}")
end

IO.puts("\n--- Продукт 2: Мляко ---")

case Repo.get_by(Product, tenant_id: tenant.id, sku: "MILK-001") do
  nil ->
    {:ok, milk} =
      %Product{}
      |> Product.changeset(%{
        tenant_id: tenant.id,
        name: "Прясно мляко 3.5% 1л",
        sku: "MILK-001",
        category: "goods",
        price: Decimal.new("2.50"),
        cost: Decimal.new("1.80")
      })
      |> Repo.insert()

    IO.puts("✓ Създаден продукт: #{milk.name}")

    # Основна единица - литър
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: milk.id,
      measurement_unit_id: unit_l.id,
      conversion_factor: Decimal.new("1"),
      is_primary: true,
      barcode: "3800020010016"
    })
    |> Repo.insert()

    IO.puts("  + Основна единица: 1 литър (баркод: 3800020010016)")

    # Кутия 12 литра
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: milk.id,
      measurement_unit_id: unit_box.id,
      conversion_factor: Decimal.new("12"),
      is_primary: false,
      barcode: "3800020010023"
    })
    |> Repo.insert()

    IO.puts("  + Кутия: 12 литра (баркод: 3800020010023)")

    # Палет 60 кутии = 720 литра
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: milk.id,
      measurement_unit_id: unit_pallet.id,
      conversion_factor: Decimal.new("720"),
      is_primary: false
    })
    |> Repo.insert()

    IO.puts("  + Палет: 60 кутии = 720л")

  existing ->
    IO.puts("- Продуктът вече съществува: #{existing.name}")
end

IO.puts("\n--- Продукт 3: Кафе ---")

case Repo.get_by(Product, tenant_id: tenant.id, sku: "COFFEE-001") do
  nil ->
    {:ok, coffee} =
      %Product{}
      |> Product.changeset(%{
        tenant_id: tenant.id,
        name: "Кафе Лаваца зърна 1кг",
        sku: "COFFEE-001",
        category: "goods",
        price: Decimal.new("25.00"),
        cost: Decimal.new("18.00")
      })
      |> Repo.insert()

    IO.puts("✓ Създаден продукт: #{coffee.name}")

    # Основна единица - kg
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: coffee.id,
      measurement_unit_id: unit_kg.id,
      conversion_factor: Decimal.new("1"),
      is_primary: true,
      barcode: "8000070001015"
    })
    |> Repo.insert()

    IO.puts("  + Основна единица: 1 kg (баркод: 8000070001015)")

    # Грамове
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: coffee.id,
      measurement_unit_id: unit_g.id,
      conversion_factor: Decimal.new("1000"),
      is_primary: false
    })
    |> Repo.insert()

    IO.puts("  + Допълнителна: 1000 g")

    # Кутия 6 пакета
    %ProductUnit{}
    |> ProductUnit.changeset(%{
      product_id: coffee.id,
      measurement_unit_id: unit_box.id,
      conversion_factor: Decimal.new("6"),
      is_primary: false,
      barcode: "8000070001022"
    })
    |> Repo.insert()

    IO.puts("  + Кутия: 6 kg (баркод: 8000070001022)")

  existing ->
    IO.puts("- Продуктът вече съществува: #{existing.name}")
end

IO.puts("\n✓ Примерни продукти създадени успешно!")
IO.puts("\nМожете да прегледате продуктите на: http://localhost:4000/products")
