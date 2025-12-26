defmodule CyberCore.Integrations.ViesValidator do
  @moduledoc """
  EU VIES (VAT Information Exchange System) валидация.
  Валидира ДДС номера в цяла Европа.
  """

  require Logger

  @vies_url "https://ec.europa.eu/taxation_customs/vies/rest-api/ms/"

  @doc """
  Валидира ДДС номер през VIES API.

  ## Примери

      iex> validate_vat("BG123456789")
      {:ok, %{
        valid: true,
        name: "КОМПАНИЯ ООД",
        address: "ул. Тест 1, София 1000",
        country_code: "BG",
        vat_number: "123456789"
      }}

      iex> validate_vat("BG999999999")
      {:error, "Invalid VAT number"}
  """
  def validate_vat(vat_number) when is_binary(vat_number) do
    with {:ok, country_code, number} <- parse_vat_number(vat_number),
         {:ok, response} <- call_vies_api(country_code, number) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Парсва ДДС номер на код на държава и номер.

  ## Примери

      iex> parse_vat_number("BG123456789")
      {:ok, "BG", "123456789"}

      iex> parse_vat_number("123456789")
      {:error, "VAT number must include country code (e.g., BG123456789)"}
  """
  def parse_vat_number(vat_number) when is_binary(vat_number) do
    vat_number = String.trim(vat_number) |> String.upcase()

    case Regex.run(~r/^([A-Z]{2})([A-Z0-9]+)$/, vat_number) do
      [_full, country_code, number] ->
        {:ok, country_code, number}

      _ ->
        {:error, "VAT number must include country code (e.g., BG123456789)"}
    end
  end

  # Извиква VIES REST API за валидация.
  defp call_vies_api(country_code, vat_number) do
    url = "#{@vies_url}#{country_code}/vat/#{vat_number}"

    Logger.info("Calling VIES API: #{url}")

    case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parse_vies_response(body, country_code, vat_number)

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, "VAT number not found in VIES registry"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("VIES API returned #{status_code}: #{body}")
        {:error, "VIES service error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("VIES API connection error: #{inspect(reason)}")
        {:error, "Connection error: #{inspect(reason)}"}
    end
  end

  # Парсва VIES XML/JSON отговор.
  defp parse_vies_response(body, country_code, vat_number) do
    try do
      case Jason.decode(body) do
        {:ok, data} ->
          {:ok,
           %{
             valid: data["isValid"] == true || data["valid"] == true,
             name: extract_name(data),
             address: extract_address(data),
             country_code: country_code,
             vat_number: vat_number,
             request_date: data["requestDate"]
           }}

        {:error, _} ->
          # Fallback to XML parsing if JSON fails
          parse_vies_xml(body, country_code, vat_number)
      end
    rescue
      e ->
        Logger.error("Error parsing VIES response: #{inspect(e)}")
        {:error, "Failed to parse VIES response"}
    end
  end

  defp parse_vies_xml(body, country_code, vat_number) do
    # Simple XML parsing for VIES SOAP response
    valid = String.contains?(body, "<valid>true</valid>")

    name =
      case Regex.run(~r/<name>(.*?)<\/name>/s, body) do
        [_, name] -> String.trim(name)
        _ -> nil
      end

    address =
      case Regex.run(~r/<address>(.*?)<\/address>/s, body) do
        [_, addr] -> String.trim(addr) |> String.replace(~r/\s+/, " ")
        _ -> nil
      end

    {:ok,
     %{
       valid: valid,
       name: name,
       address: address,
       country_code: country_code,
       vat_number: vat_number,
       request_date: DateTime.utc_now()
     }}
  end

  defp extract_name(data) do
    data["name"] || data["traderName"] || data["companyName"]
  end

  defp extract_address(data) do
    data["address"] || data["traderAddress"] || data["companyAddress"]
  end

  @doc """
  Проверява дали ДДС номерът е български.
  Ако е BG, премахва префикса и връща ЕИК.

  ## Примери

      iex> extract_bulgarian_eik("BG123456789")
      {:ok, "123456789"}

      iex> extract_bulgarian_eik("DE123456789")
      {:error, :not_bulgarian}
  """
  def extract_bulgarian_eik(vat_number) when is_binary(vat_number) do
    vat_number = String.trim(vat_number) |> String.upcase()

    case String.starts_with?(vat_number, "BG") do
      true ->
        eik = String.trim_leading(vat_number, "BG")
        {:ok, eik}

      false ->
        {:error, :not_bulgarian}
    end
  end
end
