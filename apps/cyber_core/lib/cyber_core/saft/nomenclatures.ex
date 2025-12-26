defmodule CyberCore.SAFT.Nomenclatures do
  @moduledoc """
  Context for managing SAF-T nomenclatures.
  Includes NC8/CN (Combined Nomenclature) TARIC codes for Intrastat and SAF-T.
  """
  import Ecto.Query, warn: false
  alias CyberCore.Repo
  alias CyberCore.SAFT.Nomenclature.Nc8Taric

  @doc """
  Import NC8 TARIC codes from the specified CSV file.
  Default is 2026 nomenclature.
  """
  def import_nc8_taric_codes(tenant_id, year \\ 2026) do
    csv_path = get_csv_path_for_year(year)

    unless File.exists?(csv_path) do
      {:error, "CSV file not found: #{csv_path}"}
    else
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # First delete existing codes for this tenant and year
      from(n in Nc8Taric, where: n.tenant_id == ^tenant_id and n.year == ^year)
      |> Repo.delete_all()

      count =
        File.stream!(csv_path)
        |> Stream.drop(2)  # Skip header rows (line 1: headers, line 2: column numbers)
        |> Stream.map(&parse_csv_line/1)
        |> Stream.filter(&valid_code?/1)
        |> Stream.map(fn {code, description, primary_unit, secondary_unit} ->
          %{
            tenant_id: tenant_id,
            code: normalize_code(code),
            description_bg: description,
            year: year,
            primary_unit: normalize_unit(primary_unit),
            secondary_unit: normalize_unit(secondary_unit),
            inserted_at: now,
            updated_at: now
          }
        end)
        |> Stream.chunk_every(1000)
        |> Enum.reduce(0, fn batch, acc ->
          {inserted, _} = Repo.insert_all(Nc8Taric, batch, on_conflict: :nothing)
          acc + inserted
        end)

      {:ok, "Imported #{count} NC8 TARIC codes for #{year}"}
    end
  end

  defp get_csv_path_for_year(year) do
    # Path is relative to /app in container or working directory locally
    "FILE/CN_#{year}- КН#{year}.csv"
  end

  defp parse_csv_line(line) do
    # Handle CSV with quoted fields that may contain commas
    line
    |> String.trim()
    |> String.replace("\r", "")
    |> parse_csv_fields()
    |> case do
      [code, description, primary, secondary | _] ->
        {clean_field(code), clean_field(description), clean_field(primary), clean_field(secondary)}
      [code, description, primary] ->
        {clean_field(code), clean_field(description), clean_field(primary), nil}
      [code, description] ->
        {clean_field(code), clean_field(description), nil, nil}
      _ ->
        {nil, nil, nil, nil}
    end
  end

  defp parse_csv_fields(line) do
    # Simple CSV parser that handles quoted fields
    parse_csv_fields(line, [], "", false)
  end

  defp parse_csv_fields("", acc, current, _in_quotes) do
    Enum.reverse([current | acc])
  end

  defp parse_csv_fields("\"" <> rest, acc, current, false) do
    parse_csv_fields(rest, acc, current, true)
  end

  defp parse_csv_fields("\"" <> rest, acc, current, true) do
    parse_csv_fields(rest, acc, current, false)
  end

  defp parse_csv_fields("," <> rest, acc, current, false) do
    parse_csv_fields(rest, [current | acc], "", false)
  end

  defp parse_csv_fields(<<char::utf8, rest::binary>>, acc, current, in_quotes) do
    parse_csv_fields(rest, acc, current <> <<char::utf8>>, in_quotes)
  end

  defp clean_field(nil), do: nil
  defp clean_field(str) do
    str
    |> String.trim()
    |> String.trim("\"")
    |> String.trim()
  end

  defp valid_code?({nil, _, _, _}), do: false
  defp valid_code?({"", _, _, _}), do: false
  defp valid_code?({code, _, _, _}) when is_binary(code) do
    # Valid codes start with digit or are section/chapter headers (I, II, etc.)
    String.match?(code, ~r/^[0-9]/) or String.match?(code, ~r/^[IVX]+$/)
  end
  defp valid_code?(_), do: false

  defp normalize_code(code) do
    code
    |> String.replace(" ", "")
    |> String.trim()
  end

  defp normalize_unit(nil), do: nil
  defp normalize_unit(""), do: nil
  defp normalize_unit(unit), do: String.trim(unit)

  @doc """
  List all NC8 TARIC codes for a tenant, optionally filtered by year.
  """
  def list_nc8_taric_codes(tenant_id, opts \\ []) do
    year = Keyword.get(opts, :year)

    query = from n in Nc8Taric,
      where: n.tenant_id == ^tenant_id,
      order_by: [asc: n.code]

    query =
      if year do
        from n in query, where: n.year == ^year
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Get a specific NC8 TARIC code by code and tenant.
  """
  def get_nc8_taric_code_by_code(tenant_id, code, year \\ 2026) do
    Repo.get_by(Nc8Taric, tenant_id: tenant_id, code: normalize_code(code), year: year)
  end

  @doc """
  Search NC8 TARIC codes by code or description.
  """
  def search_nc8_taric_codes(tenant_id, search_term, opts \\ []) do
    year = Keyword.get(opts, :year)
    limit = Keyword.get(opts, :limit, 100)
    search_pattern = "%#{search_term}%"

    query = from n in Nc8Taric,
      where: n.tenant_id == ^tenant_id,
      where: ilike(n.code, ^search_pattern) or ilike(n.description_bg, ^search_pattern),
      order_by: [asc: n.code],
      limit: ^limit

    query =
      if year do
        from n in query, where: n.year == ^year
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Get count of NC8 TARIC codes for a tenant.
  """
  def count_nc8_taric_codes(tenant_id, year \\ nil) do
    query = from n in Nc8Taric, where: n.tenant_id == ^tenant_id

    query =
      if year do
        from n in query, where: n.year == ^year
      else
        query
      end

    Repo.aggregate(query, :count, :id)
  end

  @doc """
  List available years for NC8 codes.
  """
  def list_available_years(tenant_id) do
    from(n in Nc8Taric,
      where: n.tenant_id == ^tenant_id,
      select: n.year,
      distinct: true,
      order_by: [desc: n.year]
    )
    |> Repo.all()
  end
end
