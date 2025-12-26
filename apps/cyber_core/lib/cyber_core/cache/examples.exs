# Примери за използване на ETS Cache System
# Може да се изпълни с: mix run apps/cyber_core/lib/cyber_core/cache/examples.exs

alias CyberCore.{Cache, Inventory, Accounting}

IO.puts("\n=== ETS Cache System Examples ===\n")

# 1. Проверка на статуса на кеша
IO.puts("1. Cache Health Check:")
health = Cache.health_check()
IO.inspect(health, label: "Health")

# 2. Статистика преди използване
IO.puts("\n2. Initial Cache Stats:")
stats = Cache.stats()
IO.inspect(stats, label: "Stats")

# 3. Взимане на мерна единица (ще зареди от БД при първо извикване)
IO.puts("\n3. Get Measurement Unit by Code 'PCE':")

case Cache.get_measurement_unit_by_code("PCE") do
  {:ok, unit} ->
    IO.puts("✓ Found: #{unit.name} (#{unit.code})")
    IO.puts("  Description: #{unit.description}")

  {:error, :not_found} ->
    IO.puts("✗ Not found - може би трябва да заредите seed данните")
end

# 4. Списък с всички мерни единици
IO.puts("\n4. List all Measurement Units (cached):")
units = Cache.list_measurement_units()
IO.puts("✓ Found #{length(units)} measurement units")

Enum.take(units, 5)
|> Enum.each(fn unit ->
  IO.puts("  - #{unit.code}: #{unit.name}")
end)

# 5. Взимане на ДДС ставка
IO.puts("\n5. Get VAT Rate by Code 'S':")

case Cache.get_vat_rate_by_code("S") do
  {:ok, rate} ->
    IO.puts("✓ Found: #{rate.description} - #{rate.rate}%")

  {:error, :not_found} ->
    IO.puts("✗ Not found")
end

# 6. Търсене на КН код
IO.puts("\n6. Search CN Code '0101':")
current_year = Date.utc_today().year
cn_codes = Cache.search_cn_codes("0101", current_year, 5)
IO.puts("✓ Found #{length(cn_codes)} CN codes")

Enum.each(cn_codes, fn cn ->
  IO.puts("  - #{cn.code}: #{cn.description_bg}")
end)

# 7. Статистика след използване
IO.puts("\n7. Cache Stats after usage:")
stats_after = Cache.stats()
IO.inspect(stats_after, label: "Stats")

# 8. Размер на таблиците
IO.puts("\n8. Cache Table Sizes:")
tables = [:cache_measurement_units, :cache_vat_rates, :cache_nomenclatures, :cache_accounts]

Enum.each(tables, fn table ->
  size = Cache.size(table)
  IO.puts("  #{table}: #{size} records")
end)

# 9. Демонстрация на invalidation
IO.puts("\n9. Cache Invalidation Demo:")

# Създаваме нова мерна единица (ако имаме права)
# IO.puts("Creating new measurement unit...")
# {:ok, new_unit} = Inventory.create_measurement_unit(%{
#   code: "TST",
#   name: "Test Unit",
#   description: "Test measurement unit",
#   saft_code: "OTH"
# })
# IO.puts("✓ Created unit: #{new_unit.code}")
# IO.puts("✓ Cache automatically invalidated")

# Или ръчно инвалидиране
IO.puts("Manual cache invalidation:")
Cache.invalidate_measurement_units()
IO.puts("✓ Measurement units cache cleared")

# 10. Reload на таблица
IO.puts("\n10. Reload table from database:")
Cache.reload(:cache_measurement_units)
IO.puts("✓ Measurement units reloaded from database")

# Финални статистики
IO.puts("\n=== Final Statistics ===")
final_stats = Cache.stats()

Enum.each(final_stats, fn
  {:hits, value} ->
    IO.puts("Cache Hits: #{value}")

  {:misses, value} ->
    IO.puts("Cache Misses: #{value}")

  {:hit_rate, value} ->
    IO.puts("Hit Rate: #{Float.round(value, 2)}%")

  {table, %{size: size, memory: memory}} when is_atom(table) ->
    memory_kb = Float.round(memory / 1024, 2)
    IO.puts("#{table}: #{size} records, #{memory_kb} KB")

  _ ->
    :ok
end)

IO.puts("\n=== Examples Completed ===\n")
