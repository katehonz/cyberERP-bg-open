defmodule CyberCore.Settings.DocumentNumbering do
  @moduledoc """
  Модул за генериране на автоматични номера на документи според ППЗДДС.

  Номерацията е 10-цифрена с водеща нула (например: 0000000001, 0000000002, ...).

  Има отделни номерации за:
  - Фактури за продажби (sales_invoice)
  - Протоколи ВОП - вътреобщностно придобиване (vop_protocol)

  ## Примери

      iex> DocumentNumbering.generate_number(1)
      "0000000001"

      iex> DocumentNumbering.generate_number(123)
      "0000000123"

      iex> DocumentNumbering.generate_number(9999999999)
      "9999999999"
  """

  alias CyberCore.Settings
  alias CyberCore.Repo
  import Ecto.Query

  @doc """
  Генерира следващ номер за фактура за продажба.

  Номерът е 10-цифрен с водеща нула.
  Автоматично увеличава брояча в настройките.

  ## Параметри

    - tenant_id: ID на фирмата (tenant)

  ## Връща

    - {:ok, number} - Генерираният номер като string (например "0000000001")
    - {:error, reason} - При грешка

  ## Примери

      {:ok, "0000000001"} = DocumentNumbering.next_sales_invoice_number(1)
      {:ok, "0000000002"} = DocumentNumbering.next_sales_invoice_number(1)
  """
  def next_sales_invoice_number(tenant_id) do
    next_number(tenant_id, :sales_invoice_next_number)
  end

  @doc """
  Генерира следващ номер за протокол ВОП (вътреобщностно придобиване).

  Номерът е 10-цифрен с водеща нула.
  Автоматично увеличава брояча в настройките.

  ## Параметри

    - tenant_id: ID на фирмата (tenant)

  ## Връща

    - {:ok, number} - Генерираният номер като string
    - {:error, reason} - При грешка
  """
  def next_vop_protocol_number(tenant_id) do
    next_number(tenant_id, :vop_protocol_next_number)
  end

  @doc """
  Форматира число във формат 10-цифрен с водеща нула.

  ## Параметри

    - number: Числото за форматиране (integer или string)

  ## Връща

    - String с 10 цифри и водещи нули

  ## Примери

      iex> DocumentNumbering.generate_number(1)
      "0000000001"

      iex> DocumentNumbering.generate_number(123)
      "0000000123"

      iex> DocumentNumbering.generate_number("456")
      "0000000456"
  """
  def generate_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.pad_leading(10, "0")
  end

  def generate_number(number) when is_binary(number) do
    case Integer.parse(number) do
      {num, _} -> generate_number(num)
      :error -> {:error, :invalid_number}
    end
  end

  @doc """
  Парсира 10-цифрен номер обратно в integer.

  ## Примери

      iex> DocumentNumbering.parse_number("0000000123")
      {:ok, 123}

      iex> DocumentNumbering.parse_number("invalid")
      {:error, :invalid_format}
  """
  def parse_number(number_string) when is_binary(number_string) do
    case Integer.parse(number_string) do
      {num, ""} -> {:ok, num}
      _ -> {:error, :invalid_format}
    end
  end

  @doc """
  Валидира дали даден номер е в правилния формат (10 цифри).

  ## Примери

      iex> DocumentNumbering.valid_number?("0000000001")
      true

      iex> DocumentNumbering.valid_number?("123")
      false

      iex> DocumentNumbering.valid_number?("abcd")
      false
  """
  def valid_number?(number_string) when is_binary(number_string) do
    String.match?(number_string, ~r/^\d{10}$/)
  end

  def valid_number?(_), do: false

  # Частни функции

  defp next_number(tenant_id, field)
       when field in [:sales_invoice_next_number, :vop_protocol_next_number] do
    Repo.transaction(fn ->
      # Заключваме записа за да избегнем race conditions
      settings =
        from(s in CyberCore.Settings.CompanySettings,
          where: s.tenant_id == ^tenant_id,
          lock: "FOR UPDATE"
        )
        |> Repo.one()

      case settings do
        nil ->
          Repo.rollback({:error, :settings_not_found})

        settings ->
          # Вземаме текущия номер
          current_number = Map.get(settings, field, 1)

          # Генерираме форматирания номер
          formatted_number = generate_number(current_number)

          # Увеличаваме брояча за следващия път
          updates = %{field => current_number + 1}

          case Settings.update_company_settings(settings, updates) do
            {:ok, _updated_settings} ->
              formatted_number

            {:error, changeset} ->
              Repo.rollback({:error, changeset})
          end
      end
    end)
  end

  defp next_number(_tenant_id, field) do
    {:error, {:invalid_field, field}}
  end

  @doc """
  Ресетва брояча на документи за даден tenant и поле.

  **ВНИМАНИЕ:** Това трябва да се използва само при специални обстоятелства,
  например в началото на нова календарна година или при миграция на данни.

  ## Параметри

    - tenant_id: ID на фирмата
    - field: :sales_invoice_next_number или :vop_protocol_next_number
    - new_value: Новата стойност (по подразбиране 1)

  ## Примери

      DocumentNumbering.reset_counter(1, :sales_invoice_next_number, 1)
  """
  def reset_counter(tenant_id, field, new_value \\ 1)
      when field in [:sales_invoice_next_number, :vop_protocol_next_number] and
             is_integer(new_value) and new_value > 0 do
    try do
      settings = Settings.get_company_settings!(tenant_id)
      updates = %{field => new_value}
      Settings.update_company_settings(settings, updates)
    rescue
      Ecto.NoResultsError -> {:error, :settings_not_found}
    end
  end

  @doc """
  Връща текущата стойност на брояча (без да го увеличава).

  ## Примери

      DocumentNumbering.current_counter(1, :sales_invoice_next_number)
      # => {:ok, 123}
  """
  def current_counter(tenant_id, field)
      when field in [:sales_invoice_next_number, :vop_protocol_next_number] do
    try do
      settings = Settings.get_company_settings!(tenant_id)
      {:ok, Map.get(settings, field, 1)}
    rescue
      Ecto.NoResultsError -> {:error, :settings_not_found}
    end
  end
end
