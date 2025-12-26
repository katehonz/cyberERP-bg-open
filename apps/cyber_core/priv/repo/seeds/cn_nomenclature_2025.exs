# Script за импорт на Комбинирана номенклатура КН8 за 2025 г.
# Стартира се с: mix run priv/repo/seeds/cn_nomenclature_2025.exs

alias CyberCore.Inventory.CnImporter

# Път до CSV файла (релативно спрямо root на проекта)
csv_path = Path.join([File.cwd!(), "..", "..", "FILE", "INTRASTAT", "CN_2025_NAP (1.csv"])

IO.puts("Започва импорт на КН номенклатура за 2025 г.")
IO.puts("CSV файл: #{csv_path}")

if File.exists?(csv_path) do
  case CnImporter.import_from_csv(csv_path, 2025) do
    {:ok, %{success: success, errors: errors}} ->
      IO.puts("\n✓ Импорт завършен успешно!")
      IO.puts("  Импортирани записи: #{success}")
      IO.puts("  Грешки: #{errors}")

    {:error, reason} ->
      IO.puts("\n✗ Грешка при импорт: #{inspect(reason)}")
  end
else
  IO.puts("\n✗ CSV файлът не е намерен: #{csv_path}")
  IO.puts("Моля, проверете пътя до файла.")
end
