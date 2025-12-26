defmodule CyberCore.Inventory.CnImporter do
  @moduledoc """
  Импортиране на Комбинирана номенклатура КН8 от CSV файл.
  """

  alias CyberCore.Repo
  alias CyberCore.Inventory.CnNomenclature
  require Logger

  @doc """
  Импортира КН номенклатура от CSV файл за дадена година.

  ## Параметри
    - file_path: Път до CSV файла
    - year: Година на номенклатурата (напр. 2025)

  ## Пример
      CyberCore.Inventory.CnImporter.import_from_csv("FILE/INTRASTAT/CN_2025_NAP (1.csv", 2025)
  """
  def import_from_csv(file_path, year) do
    Logger.info("Започва импорт на КН номенклатура за #{year} от #{file_path}")

    file_path
    |> File.stream!()
    |> CSV.decode!(headers: true, separator: ?,)
    |> Stream.with_index(1)
    |> Stream.filter(&valid_row?/1)
    |> Stream.map(&parse_row(&1, year))
    |> Enum.reduce({0, 0}, fn row_data, {success, errors} ->
      case insert_nomenclature(row_data) do
        {:ok, _} ->
          {success + 1, errors}

        {:error, changeset} ->
          Logger.error("Грешка при импорт на код #{row_data.code}: #{inspect(changeset.errors)}")
          {success, errors + 1}
      end
    end)
    |> then(fn {success, errors} ->
      Logger.info("Импорт завършен: #{success} успешни, #{errors} грешки")
      {:ok, %{success: success, errors: errors}}
    end)
  end

  # Проверява дали редът от CSV е валиден за импорт.
  # Прескача празни редове и редове с описания на раздели/глави.
  defp valid_row?({row, _index}) do
    code = Map.get(row, "Код по КН", "") |> String.trim()
    description = Map.get(row, "Описание на стоката", "") |> String.trim()

    # Валиден е редът, ако има код и описание
    # Кодът трябва да съдържа цифри (не само букви като "I", "01" и т.н.)
    code != "" && description != "" && String.match?(code, ~r/\d/)
  end

  # Парсва ред от CSV и го преобразува в map за вмъкване в БД.
  defp parse_row({row, _index}, year) do
    code = Map.get(row, "Код по КН", "") |> clean_code()
    description = Map.get(row, "Описание на стоката", "") |> String.trim()
    primary_unit = Map.get(row, "Основна мерна единица", "") |> clean_unit()
    supplementary_unit = Map.get(row, "Допълнителна мерна единица", "") |> clean_unit()

    %{
      code: code,
      description: description,
      year: year,
      primary_unit: primary_unit,
      supplementary_unit: supplementary_unit,
      is_active: true
    }
  end

  # Почиства кода на номенклатурата - премахва интервали.
  defp clean_code(code) do
    code
    |> String.trim()
    |> String.replace(" ", "")
  end

  # Почиства мерната единица - връща nil ако е празна.
  defp clean_unit(unit) do
    case String.trim(unit) do
      "" -> nil
      cleaned -> cleaned
    end
  end

  # Вмъква номенклатура в БД.
  defp insert_nomenclature(data) do
    case Repo.get_by(CnNomenclature, code: data.code, year: data.year) do
      nil ->
        %CnNomenclature{}
        |> CnNomenclature.changeset(data)
        |> Repo.insert()

      existing ->
        # Ако вече съществува, обновяваме данните
        existing
        |> CnNomenclature.changeset(data)
        |> Repo.update()
    end
  end

  @doc """
  Изтрива всички номенклатури за дадена година.
  """
  def delete_all_for_year(year) do
    import Ecto.Query

    from(cn in CnNomenclature, where: cn.year == ^year)
    |> Repo.delete_all()
  end
end
