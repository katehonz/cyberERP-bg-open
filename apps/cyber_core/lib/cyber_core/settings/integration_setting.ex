defmodule CyberCore.Settings.IntegrationSetting do
  @moduledoc """
  Settings за външни интеграции (Azure, S3, и др.)

  Credentials се съхраняват в config map поле.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @integration_types ~w(azure_form_recognizer s3_storage mistral_ai smtp email_provider payment_gateway)

  schema "integration_settings" do
    field :tenant_id, :integer
    field :integration_type, :string
    field :name, :string
    field :enabled, :boolean, default: true
    field :config, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(integration_setting, attrs) do
    integration_setting
    |> cast(attrs, [:tenant_id, :integration_type, :name, :enabled, :config])
    |> validate_required([:tenant_id, :integration_type, :name])
    |> validate_inclusion(:integration_type, @integration_types)
    |> validate_config()
    |> unique_constraint([:tenant_id, :integration_type, :name])
  end

  defp validate_config(changeset) do
    integration_type = get_field(changeset, :integration_type)
    config = get_field(changeset, :config) || %{}

    case integration_type do
      "azure_form_recognizer" ->
        validate_azure_config(changeset, config)

      "s3_storage" ->
        validate_s3_config(changeset, config)

      "mistral_ai" ->
        validate_mistral_config(changeset, config)

      "smtp" ->
        validate_smtp_config(changeset, config)

      _ ->
        changeset
    end
  end

  defp validate_azure_config(changeset, config) do
    required_keys = ["endpoint", "api_key"]
    missing_keys = required_keys -- Map.keys(config)

    if missing_keys == [] do
      changeset
    else
      add_error(changeset, :config, "missing required keys: #{Enum.join(missing_keys, ", ")}")
    end
  end

  defp validate_s3_config(changeset, config) do
    required_keys = ["access_key_id", "secret_access_key", "host", "bucket"]
    missing_keys = required_keys -- Map.keys(config)

    if missing_keys == [] do
      changeset
    else
      add_error(changeset, :config, "missing required keys: #{Enum.join(missing_keys, ", ")}")
    end
  end

  defp validate_mistral_config(changeset, config) do
    required_keys = ["api_key"]
    missing_keys = required_keys -- Map.keys(config)

    if missing_keys == [] do
      changeset
    else
      add_error(changeset, :config, "missing required keys: #{Enum.join(missing_keys, ", ")}")
    end
  end

  defp validate_smtp_config(changeset, config) do
    required_keys = ["host", "port", "username", "password", "from_email"]
    missing_keys = required_keys -- Map.keys(config)

    if missing_keys == [] do
      changeset
    else
      add_error(changeset, :config, "missing required keys: #{Enum.join(missing_keys, ", ")}")
    end
  end

  @doc """
  Helper за създаване на Azure Form Recognizer настройка.
  """
  def azure_form_recognizer_attrs(tenant_id, endpoint, api_key, name \\ "default") do
    %{
      tenant_id: tenant_id,
      integration_type: "azure_form_recognizer",
      name: name,
      enabled: true,
      config: %{
        "endpoint" => endpoint,
        "api_key" => api_key,
        "api_version" => "2024-11-30"
      }
    }
  end

  @doc """
  Helper за създаване на S3 настройка.
  """
  def s3_storage_attrs(tenant_id, access_key, secret_key, host, bucket, name \\ "default") do
    %{
      tenant_id: tenant_id,
      integration_type: "s3_storage",
      name: name,
      enabled: true,
      config: %{
        "access_key_id" => access_key,
        "secret_access_key" => secret_key,
        "host" => host,
        "bucket" => bucket,
        "scheme" => "https://",
        "port" => 443,
        "region" => "eu-central"
      }
    }
  end

  @doc """
  Helper за създаване на Mistral AI настройка.
  """
  def mistral_ai_attrs(tenant_id, api_key, name \\ "default") do
    %{
      tenant_id: tenant_id,
      integration_type: "mistral_ai",
      name: name,
      enabled: true,
      config: %{
        "api_key" => api_key,
        "model" => "mistral-small-latest"
      }
    }
  end

  @doc """
  Helper за създаване на SMTP настройка.
  """
  def smtp_attrs(tenant_id, host, port, username, password, from_email, opts \\ []) do
    %{
      tenant_id: tenant_id,
      integration_type: "smtp",
      name: Keyword.get(opts, :name, "default"),
      enabled: true,
      config: %{
        "host" => host,
        "port" => port,
        "username" => username,
        "password" => password,
        "from_email" => from_email,
        "from_name" => Keyword.get(opts, :from_name, "Cyber ERP"),
        "ssl" => Keyword.get(opts, :ssl, true),
        "tls" => Keyword.get(opts, :tls, :if_available),
        "auth" => Keyword.get(opts, :auth, :always)
      }
    }
  end

  def valid_integration_types, do: @integration_types
end
