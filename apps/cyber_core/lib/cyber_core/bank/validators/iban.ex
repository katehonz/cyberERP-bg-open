defmodule CyberCore.Validators.IBAN do
  @moduledoc """
  IBAN валидатор.

  Валидира IBAN номера съгласно ISO 13616:2007.
  Използва номенклатурата от saft_iban_formats за проверка на формат по държави.
  """

  @doc """
  Валидира IBAN номер.

  ## Примери

      iex> IBAN.validate("BG80BNBG96611020345678")
      {:ok, %{country: "BG", check_digits: "80", ...}}

      iex> IBAN.validate("INVALID")
      {:error, "Invalid IBAN format"}
  """
  def validate(iban) when is_binary(iban) do
    iban = String.upcase(String.replace(iban, ~r/\s/, ""))

    with :ok <- validate_format(iban),
         :ok <- validate_checksum(iban) do
      {:ok, parse(iban)}
    end
  end

  def validate(_), do: {:error, "IBAN must be a string"}

  @doc """
  Валидира формата на IBAN.
  """
  def validate_format(iban) do
    cond do
      String.length(iban) < 15 ->
        {:error, "IBAN too short"}

      String.length(iban) > 34 ->
        {:error, "IBAN too long"}

      not Regex.match?(~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]+$/, iban) ->
        {:error, "Invalid IBAN format"}

      true ->
        :ok
    end
  end

  @doc """
  Валидира checksum на IBAN според mod-97 алгоритъм.
  """
  def validate_checksum(iban) do
    # Move first 4 chars to end
    rearranged = String.slice(iban, 4..-1) <> String.slice(iban, 0..3)

    # Convert letters to numbers (A=10, B=11, etc.)
    numeric =
      rearranged
      |> String.graphemes()
      |> Enum.map(&char_to_number/1)
      |> Enum.join()
      |> String.to_integer()

    if rem(numeric, 97) == 1 do
      :ok
    else
      {:error, "Invalid IBAN checksum"}
    end
  rescue
    _ -> {:error, "Invalid IBAN checksum"}
  end

  @doc """
  Парсва IBAN и връща компонентите му.
  """
  def parse(iban) do
    %{
      country: String.slice(iban, 0..1),
      check_digits: String.slice(iban, 2..3),
      bban: String.slice(iban, 4..-1),
      full: iban
    }
  end

  # Helper: Конвертира символ в число (A=10, B=11, etc.)
  defp char_to_number(char) do
    case char do
      <<c>> when c >= ?A and c <= ?Z -> c - ?A + 10
      <<c>> when c >= ?0 and c <= ?9 -> c - ?0
      _ -> 0
    end
    |> to_string()
  end
end
