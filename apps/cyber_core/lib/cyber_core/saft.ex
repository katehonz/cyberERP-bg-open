defmodule CyberCore.SAFT do
  @moduledoc """
  SAF-T (Standard Audit File for Tax) модул за България.

  Пълна имплементация на SAF-T съгласно BG Schema V 1.0.1.

  ## Видове отчети

  - **Месечен (Monthly)** - MasterFiles + GeneralLedgerEntries + SourceDocuments
  - **При поискване (OnDemand)** - PhysicalStock + MovementOfGoods
  - **Годишен (Annual)** - Assets + AssetTransactions

  ## Структура на файла

  ```xml
  <AuditFile>
    <Header>...</Header>
    <MasterFilesMonthly>...</MasterFilesMonthly>      <!-- или MasterFilesOnDemand/MasterFilesAnnual -->
    <GeneralLedgerEntries>...</GeneralLedgerEntries>  <!-- само за Monthly -->
    <SourceDocumentsMonthly>...</SourceDocumentsMonthly>
  </AuditFile>
  ```

  ## Номенклатури

  Всички номенклатури се намират в `CyberCore.SAFT.Nomenclature.*`:
  - InvoiceType - Видове фактури (01-95)
  - PaymentMethod - Методи на плащане (01-03) и механизми (10-99)
  - Country - ISO 3166-1 държави
  - Currency - ISO 4217 валути
  - StockMovementType - Движения на запаси (10-180)
  - InventoryType - Видове материални запаси (10-50)
  - VatTaxType - ДДС режими (100010-100030)
  - AssetMovementType - Движения на активи (10-80)
  - NraAccount - Сметкоплан НАП
  - MeasurementUnit - Мерни единици

  ## Използване

  ```elixir
  # Генериране на месечен отчет
  {:ok, xml} = CyberCore.SAFT.generate(:monthly, tenant_id, year: 2025, month: 1)

  # Генериране на годишен отчет за активи
  {:ok, xml} = CyberCore.SAFT.generate(:annual, tenant_id, year: 2025)

  # Генериране при поискване (складови наличности)
  {:ok, xml} = CyberCore.SAFT.generate(:on_demand, tenant_id,
    start_date: ~D[2025-01-01],
    end_date: ~D[2025-01-31]
  )

  # Записване във файл
  CyberCore.SAFT.export(:monthly, tenant_id, "/path/to/saft.xml", year: 2025, month: 1)

  # Валидация на XML срещу XSD схема
  {:ok, :valid} = CyberCore.SAFT.validate_xml(xml_content)
  ```
  """

  alias CyberCore.SAFT.{Header, MasterFiles, GeneralLedgerEntries, SourceDocuments}
  alias CyberCore.Settings

  @namespace "mf:nra:dgti:dxxxx:declaration:v1"
  @schema_version "007"
  @country "BG"

  @type report_type :: :monthly | :annual | :on_demand
  @type generation_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Генерира SAF-T XML файл.

  ## Параметри

  - `type` - Тип на отчета: `:monthly`, `:annual`, или `:on_demand`
  - `tenant_id` - ID на фирмата
  - `opts` - Опции:
    - `:year` - Година (задължително)
    - `:month` - Месец (само за monthly)
    - `:start_date` - Начална дата (за on_demand)
    - `:end_date` - Крайна дата (за on_demand)

  ## Примери

      iex> CyberCore.SAFT.generate(:monthly, 1, year: 2025, month: 1)
      {:ok, "<?xml version=\\"1.0\\" ..."}

      iex> CyberCore.SAFT.generate(:annual, 1, year: 2025)
      {:ok, "<?xml version=\\"1.0\\" ..."}
  """
  @spec generate(report_type(), integer(), keyword()) :: generation_result()
  def generate(type, tenant_id, opts \\ [])

  def generate(:monthly, tenant_id, opts) do
    with {:ok, tenant} <- get_tenant(tenant_id),
         {:ok, year} <- get_required_opt(opts, :year),
         {:ok, month} <- get_required_opt(opts, :month),
         {:ok, header} <- Header.build(:monthly, tenant, year: year, month: month),
         {:ok, master_files} <- MasterFiles.build(:monthly, tenant_id, year: year, month: month),
         {:ok, gl_entries} <- GeneralLedgerEntries.build(tenant_id, year: year, month: month),
         {:ok, source_docs} <- SourceDocuments.build(:monthly, tenant_id, year: year, month: month) do
      xml =
        build_xml_document([
          header,
          master_files,
          gl_entries,
          source_docs
        ])

      {:ok, xml}
    end
  end

  def generate(:annual, tenant_id, opts) do
    with {:ok, tenant} <- get_tenant(tenant_id),
         {:ok, year} <- get_required_opt(opts, :year),
         {:ok, header} <- Header.build(:annual, tenant, year: year),
         {:ok, master_files} <- MasterFiles.build(:annual, tenant_id, year: year),
         {:ok, source_docs} <- SourceDocuments.build(:annual, tenant_id, year: year) do
      xml =
        build_xml_document([
          header,
          master_files,
          source_docs
        ])

      {:ok, xml}
    end
  end

  def generate(:on_demand, tenant_id, opts) do
    with {:ok, tenant} <- get_tenant(tenant_id),
         {:ok, start_date} <- get_required_opt(opts, :start_date),
         {:ok, end_date} <- get_required_opt(opts, :end_date),
         {:ok, header} <- Header.build(:on_demand, tenant, start_date: start_date, end_date: end_date),
         {:ok, master_files} <- MasterFiles.build(:on_demand, tenant_id, start_date: start_date, end_date: end_date),
         {:ok, source_docs} <- SourceDocuments.build(:on_demand, tenant_id, start_date: start_date, end_date: end_date) do
      xml =
        build_xml_document([
          header,
          master_files,
          source_docs
        ])

      {:ok, xml}
    end
  end

  @doc """
  Експортира SAF-T XML във файл.
  """
  @spec export(report_type(), integer(), String.t(), keyword()) :: :ok | {:error, term()}
  def export(type, tenant_id, file_path, opts \\ []) do
    with {:ok, xml} <- generate(type, tenant_id, opts) do
      File.write(file_path, xml)
    end
  end

  @doc """
  Валидира XML съдържание срещу SAF-T XSD схема.
  """
  @spec validate_xml(String.t()) :: {:ok, :valid} | {:error, list()}
  def validate_xml(xml_content) do
    xsd_path = Path.join(:code.priv_dir(:cyber_core), "saft/BG_SAFT_Schema_V_1.0.1.xsd")
    # erlsom expects a charlist for the path
    xsd_path_charlist = to_charlist(xsd_path)

    case File.exists?(xsd_path) do
      true ->
        case :erlsom.compile_xsd_file(xsd_path_charlist) do
          {:ok, model} ->
            case :erlsom.scan(to_charlist(xml_content), model) do
              {:ok, _erlang_structure, _rest} ->
                {:ok, :valid}
              {:error, reason, _} ->
                {:error, reason}
            end
          {:error, reason} ->
            {:error, reason}
        end
      false ->
        {:error, :xsd_not_found}
    end
  end

  @doc """
  Връща XML namespace за SAF-T.
  """
  def namespace, do: @namespace

  @doc """
  Връща версията на схемата.
  """
  def schema_version, do: @schema_version

  @doc """
  Връща кода на държавата.
  """
  def country, do: @country

  # Private functions

  defp get_tenant(tenant_id) do
    case Settings.get_or_create_company_settings(tenant_id) do
      {:ok, settings} -> {:ok, normalize_tenant(settings)}
      {:error, _} -> {:error, :tenant_not_found}
    end
  end

  defp normalize_tenant(settings) do
    %{
      id: settings.tenant_id,
      name: settings.company_name,
      eik: settings.eik,
      vat_number: settings.vat_number,
      is_vat_registered: settings.is_vat_registered,
      address: %{
        street: settings.address,
        city: settings.city,
        postal_code: settings.postal_code,
        country: settings.country || "BG"
      },
      city: settings.city,
      postal_code: settings.postal_code,
      phone: settings.phone,
      email: settings.email,
      mol: settings.mol_name,
      contact_name: settings.mol_name,
      iban: settings.bank_iban,
      default_currency: settings.default_currency || "BGN",
      region_code: "22",  # София-град по подразбиране
      tax_basis: "A",     # Търговско предприятие
      owner_name: settings.mol_name,
      owner_egn: nil
    }
  end

  defp get_required_opt(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_option, key}}
    end
  end

  defp build_xml_document(elements) do
    content = Enum.join(elements, "\n")

    """
    <?xml version="1.0" encoding="utf-8"?>
    <nsSAFT:AuditFile xmlns:doc="urn:schemas-OECD:schema-extensions:documentation xml:lang=en" xmlns:nsSAFT="#{@namespace}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    #{content}
    </nsSAFT:AuditFile>
    """
  end
end
