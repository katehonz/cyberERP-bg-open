defmodule CyberCore.Settings do
  @moduledoc """
  Контекст за управление на настройки на фирмата.
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo
  alias CyberCore.Settings.{CompanySettings, IntegrationSetting, AccountingSettings}

  ## Accounting Settings

  @doc """
  Взима счетоводните настройки за даден tenant.
  Ако не съществуват, създава празни.
  """
  def get_or_create_accounting_settings(tenant_id) do
    case Repo.get_by(AccountingSettings, tenant_id: tenant_id) do
      nil ->
        create_accounting_settings(%{tenant_id: tenant_id})

      settings ->
        {:ok, Repo.preload(settings, [:suppliers_account, :customers_account, :cash_account, :vat_sales_account, :vat_purchases_account, :default_income_account])}
    end
  end

  @doc """
  Създава нови счетоводни настройки.
  """
  def create_accounting_settings(attrs \\ %{}) do
    %AccountingSettings{}
    |> AccountingSettings.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Обновява счетоводните настройки.
  """
  def update_accounting_settings(%AccountingSettings{} = settings, attrs) do
    settings
    |> AccountingSettings.changeset(attrs)
    |> Repo.update()
  end


  ## Document Uploads

  @doc """
  Взима настройките за даден tenant.
  Ако не съществуват, създава празни с подразбиращи се стойности.
  """
  def get_or_create_company_settings(tenant_id) do
    case Repo.get_by(CompanySettings, tenant_id: tenant_id) do
      nil ->
        create_company_settings(%{
          tenant_id: tenant_id,
          company_name: "Моята фирма",
          vat_number: "BG999999999",
          is_vat_registered: true,
          country: "BG",
          default_currency: "BGN",
          default_vat_rate: Decimal.new("20.00")
        })

      settings ->
        {:ok, settings}
    end
  end

  @doc """
  Взима настройките за даден tenant или връща грешка.
  """
  def get_company_settings!(tenant_id) do
    Repo.get_by!(CompanySettings, tenant_id: tenant_id)
  end

  @doc """
  Създава нови настройки за фирма.
  """
  def create_company_settings(attrs \\ %{}) do
    %CompanySettings{}
    |> CompanySettings.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Обновява настройките за фирма.
  """
  def update_company_settings(%CompanySettings{} = settings, attrs) do
    settings
    |> CompanySettings.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Създава changeset за настройките.
  """
  def change_company_settings(%CompanySettings{} = settings, attrs \\ %{}) do
    CompanySettings.changeset(settings, attrs)
  end

  @doc """
  Проверява дали фирмата е регистрирана по ДДС.
  """
  def is_vat_registered?(tenant_id) do
    case get_or_create_company_settings(tenant_id) do
      {:ok, settings} -> settings.is_vat_registered
      _ -> false
    end
  end

  @doc """
  Взима ДДС номера на фирмата.
  """
  def get_vat_number(tenant_id) do
    case get_or_create_company_settings(tenant_id) do
      {:ok, settings} -> settings.vat_number
      _ -> "BG999999999"
    end
  end

  @doc """
  Взима основната валута на фирмата.
  """
  def get_default_currency(tenant_id) do
    case get_or_create_company_settings(tenant_id) do
      {:ok, settings} -> settings.default_currency
      _ -> "BGN"
    end
  end

  ## Integration Settings

  @doc """
  Връща списък с integration settings за tenant.
  """
  def list_integration_settings(tenant_id, opts \\ []) do
    integration_type = Keyword.get(opts, :integration_type)

    IntegrationSetting
    |> where(tenant_id: ^tenant_id)
    |> maybe_filter_by_type(integration_type)
    |> order_by([s], [s.integration_type, s.name])
    |> Repo.all()
  end

  defp maybe_filter_by_type(query, nil), do: query
  defp maybe_filter_by_type(query, type), do: where(query, integration_type: ^type)

  @doc """
  Връща integration setting по тип и име.
  """
  def get_integration_setting(tenant_id, integration_type, name \\ "default") do
    case Repo.get_by(IntegrationSetting,
           tenant_id: tenant_id,
           integration_type: integration_type,
           name: name
         ) do
      nil -> {:error, :not_found}
      setting -> {:ok, setting}
    end
  end

  @doc """
  Връща integration setting по ID.
  """
  def get_integration_setting!(id) do
    Repo.get!(IntegrationSetting, id)
  end

  @doc """
  Създава нова integration setting.
  """
  def create_integration_setting(attrs \\ %{}) do
    %IntegrationSetting{}
    |> IntegrationSetting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира integration setting.
  """
  def update_integration_setting(%IntegrationSetting{} = setting, attrs) do
    setting
    |> IntegrationSetting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изтрива integration setting.
  """
  def delete_integration_setting(%IntegrationSetting{} = setting) do
    Repo.delete(setting)
  end

  @doc """
  Changeset за валидация.
  """
  def change_integration_setting(%IntegrationSetting{} = setting, attrs \\ %{}) do
    IntegrationSetting.changeset(setting, attrs)
  end

  ## Helper functions for specific integrations

  @doc """
  Създава или актуализира Azure Form Recognizer настройка.
  """
  def upsert_azure_form_recognizer(tenant_id, endpoint, api_key, name \\ "default") do
    attrs = IntegrationSetting.azure_form_recognizer_attrs(tenant_id, endpoint, api_key, name)

    case get_integration_setting(tenant_id, "azure_form_recognizer", name) do
      {:ok, existing} ->
        update_integration_setting(existing, attrs)

      {:error, :not_found} ->
        create_integration_setting(attrs)
    end
  end

  @doc """
  Създава или актуализира S3 Storage настройка.
  """
  def upsert_s3_storage(tenant_id, access_key, secret_key, host, bucket, name \\ "default") do
    attrs =
      IntegrationSetting.s3_storage_attrs(tenant_id, access_key, secret_key, host, bucket, name)

    case get_integration_setting(tenant_id, "s3_storage", name) do
      {:ok, existing} ->
        update_integration_setting(existing, attrs)

      {:error, :not_found} ->
        create_integration_setting(attrs)
    end
  end

  @doc """
  Създава или актуализира Mistral AI настройка.
  """
  def upsert_mistral_ai(tenant_id, api_key, name \\ "default") do
    attrs = IntegrationSetting.mistral_ai_attrs(tenant_id, api_key, name)

    case get_integration_setting(tenant_id, "mistral_ai", name) do
      {:ok, existing} ->
        update_integration_setting(existing, attrs)

      {:error, :not_found} ->
        create_integration_setting(attrs)
    end
  end

  @doc """
  Създава или актуализира SMTP настройка.
  """
  def upsert_smtp(tenant_id, host, port, username, password, from_email, opts \\ []) do
    attrs = IntegrationSetting.smtp_attrs(tenant_id, host, port, username, password, from_email, opts)
    name = Keyword.get(opts, :name, "default")

    case get_integration_setting(tenant_id, "smtp", name) do
      {:ok, existing} ->
        update_integration_setting(existing, attrs)

      {:error, :not_found} ->
        create_integration_setting(attrs)
    end
  end

  @doc """
  Взима SMTP настройките за даден tenant.
  """
  def get_smtp_settings(tenant_id, name \\ "default") do
    case get_integration_setting(tenant_id, "smtp", name) do
      {:ok, %{config: config, enabled: true}} ->
        {:ok, config}

      {:ok, %{enabled: false}} ->
        {:error, :smtp_disabled}

      {:error, :not_found} ->
        {:error, :smtp_not_configured}
    end
  end

  @doc """
  Проверява дали integration е enabled за tenant.
  """
  def integration_enabled?(tenant_id, integration_type, name \\ "default") do
    case get_integration_setting(tenant_id, integration_type, name) do
      {:ok, %{enabled: true}} -> true
      _ -> false
    end
  end

  @doc """
  Toggle enabled status на integration.
  """
  def toggle_integration(tenant_id, integration_type, name \\ "default") do
    case get_integration_setting(tenant_id, integration_type, name) do
      {:ok, setting} ->
        update_integration_setting(setting, %{enabled: !setting.enabled})

      {:error, _} = error ->
        error
    end
  end
end
