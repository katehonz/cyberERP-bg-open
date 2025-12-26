defmodule CyberCore.Integrations.MistralAddressParser do
  @moduledoc """
  Парсира адреси с Mistral AI.
  Разделя пълен адрес на компоненти (улица, номер, град, пощенски код и т.н.)
  """

  require Logger

  @mistral_api_url "https://api.mistral.ai/v1/chat/completions"
  @model "mistral-small-latest"

  @doc """
  Парсира адрес с Mistral AI.

  ## Примери

      iex> parse_address("ул. Витоша 1, София 1000, България", tenant_id: 1)
      {:ok, %{
        street_name: "Витоша",
        building_number: "1",
        city: "София",
        postal_code: "1000",
        country: "България",
        region: nil
      }}

      iex> parse_address("ул. Витоша 1, София 1000, България", api_key: "sk-...")
      {:ok, %{...}}
  """
  def parse_address(address, opts \\ []) when is_binary(address) do
    api_key = get_api_key(opts)

    if is_nil(api_key) or api_key == "" do
      {:error, "Mistral AI API key not configured"}
    else
      prompt = build_address_parsing_prompt(address)

      case call_mistral_api(prompt, api_key) do
        {:ok, response} -> parse_mistral_response(response)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Връща Mistral API key от настройките или от опции.
  defp get_api_key(opts) when is_list(opts) do
    cond do
      # Explicit API key passed
      Keyword.has_key?(opts, :api_key) ->
        Keyword.get(opts, :api_key)

      # Tenant ID passed - get from Settings
      Keyword.has_key?(opts, :tenant_id) ->
        tenant_id = Keyword.get(opts, :tenant_id)
        get_api_key_from_settings(tenant_id)

      # Fallback to environment variable
      true ->
        System.get_env("MISTRAL_API_KEY")
    end
  end

  # Взема API key от настройките на tenant.
  defp get_api_key_from_settings(tenant_id) do
    case CyberCore.Settings.get_integration_setting(tenant_id, "mistral_ai") do
      {:ok, %{enabled: true, config: %{"api_key" => api_key}}} ->
        api_key

      _ ->
        nil
    end
  end

  # Създава prompt за парсиране на адрес.
  defp build_address_parsing_prompt(address) do
    """
    Parse the following address into structured components. Return ONLY a JSON object, no additional text.

    Address: #{address}

    Expected JSON format:
    {
      "street_name": "street name without number",
      "building_number": "building number",
      "city": "city name",
      "postal_code": "postal code",
      "country": "country name",
      "region": "region/state if applicable",
      "additional_details": "floor, apartment, etc. if applicable"
    }

    Rules:
    - Extract only the information present in the address
    - Use null for missing fields
    - For Bulgarian addresses, handle prefixes like "ул." (улица), "бул." (булевард), "пл." (площад)
    - Return ONLY the JSON object, nothing else
    """
  end

  # Извиква Mistral AI API.
  defp call_mistral_api(prompt, api_key) do
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: @model,
        messages: [
          %{
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.1,
        max_tokens: 500
      })

    Logger.info("Calling Mistral AI API for address parsing")

    case HTTPoison.post(@mistral_api_url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, data} ->
            content = get_in(data, ["choices", Access.at(0), "message", "content"])
            {:ok, content}

          {:error, reason} ->
            Logger.error("Failed to parse Mistral response: #{inspect(reason)}")
            {:error, "Failed to parse Mistral response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        Logger.error("Mistral API returned #{status_code}: #{error_body}")
        {:error, "Mistral API error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Mistral API connection error: #{inspect(reason)}")
        {:error, "Connection error: #{inspect(reason)}"}
    end
  end

  # Парсва отговора от Mistral AI.
  defp parse_mistral_response(content) when is_binary(content) do
    # Extract JSON from response (Mistral might wrap it in markdown)
    json_content =
      content
      |> String.replace("```json", "")
      |> String.replace("```", "")
      |> String.trim()

    case Jason.decode(json_content) do
      {:ok, data} ->
        {:ok,
         %{
           street_name: data["street_name"],
           building_number: data["building_number"],
           city: data["city"],
           postal_code: data["postal_code"],
           country: data["country"],
           region: data["region"],
           additional_address_detail: data["additional_details"]
         }}

      {:error, reason} ->
        Logger.error("Failed to parse Mistral JSON response: #{inspect(reason)}")
        Logger.debug("Raw content: #{content}")
        {:error, "Failed to parse address components"}
    end
  end
end
