defmodule CyberCore.SAFT.Header do
  @moduledoc """
  Генерира Header секцията на SAF-T файла.

  Header съдържа:
  - Информация за версията на файла
  - Данни за фирмата (Company)
  - Собственост (Ownership)
  - Критерии за селекция (SelectionCriteria)
  - Тип на отчета (TaxAccountingBasis)
  """

  alias CyberCore.SAFT

  @doc """
  Изгражда Header секцията.

  ## Параметри

  - `type` - Тип на отчета: `:monthly`, `:annual`, или `:on_demand`
  - `tenant` - Tenant структура с данни за фирмата
  - `opts` - Опции за периода
  """
  def build(type, tenant, opts \\ [])

  def build(:monthly, tenant, opts) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)

    selection_criteria = """
        <nsSAFT:SelectionCriteria>
          <nsSAFT:TaxReportingJurisdiction>NRA</nsSAFT:TaxReportingJurisdiction>
          <nsSAFT:CompanyEntity/>
          <nsSAFT:PeriodStart>#{month}</nsSAFT:PeriodStart>
          <nsSAFT:PeriodStartYear>#{year}</nsSAFT:PeriodStartYear>
          <nsSAFT:PeriodEnd>#{month}</nsSAFT:PeriodEnd>
          <nsSAFT:PeriodEndYear>#{year}</nsSAFT:PeriodEndYear>
          <nsSAFT:DocumentType/>
          <nsSAFT:OtherCriteria/>
        </nsSAFT:SelectionCriteria>
    """

    {:ok, build_header(tenant, selection_criteria, "M")}
  end

  def build(:annual, tenant, opts) do
    year = Keyword.fetch!(opts, :year)

    selection_criteria = """
        <nsSAFT:SelectionCriteria>
          <nsSAFT:TaxReportingJurisdiction>NRA</nsSAFT:TaxReportingJurisdiction>
          <nsSAFT:CompanyEntity/>
          <nsSAFT:SelectionStartDate>#{year}-01-01</nsSAFT:SelectionStartDate>
          <nsSAFT:SelectionEndDate>#{year}-12-31</nsSAFT:SelectionEndDate>
          <nsSAFT:DocumentType/>
          <nsSAFT:OtherCriteria/>
        </nsSAFT:SelectionCriteria>
    """

    {:ok, build_header(tenant, selection_criteria, "A")}
  end

  def build(:on_demand, tenant, opts) do
    start_date = Keyword.fetch!(opts, :start_date)
    end_date = Keyword.fetch!(opts, :end_date)

    selection_criteria = """
        <nsSAFT:SelectionCriteria>
          <nsSAFT:TaxReportingJurisdiction>NRA</nsSAFT:TaxReportingJurisdiction>
          <nsSAFT:CompanyEntity/>
          <nsSAFT:SelectionStartDate>#{Date.to_iso8601(start_date)}</nsSAFT:SelectionStartDate>
          <nsSAFT:SelectionEndDate>#{Date.to_iso8601(end_date)}</nsSAFT:SelectionEndDate>
          <nsSAFT:DocumentType/>
          <nsSAFT:OtherCriteria/>
        </nsSAFT:SelectionCriteria>
    """

    {:ok, build_header(tenant, selection_criteria, "D")}
  end

  defp build_header(tenant, selection_criteria, header_comment) do
    today = Date.utc_today() |> Date.to_iso8601()
    region = get_region(tenant)

    """
      <nsSAFT:Header>
        <nsSAFT:AuditFileVersion>#{SAFT.schema_version()}</nsSAFT:AuditFileVersion>
        <nsSAFT:AuditFileCountry>#{SAFT.country()}</nsSAFT:AuditFileCountry>
        <nsSAFT:AuditFileRegion>#{region}</nsSAFT:AuditFileRegion>
        <nsSAFT:AuditFileDateCreated>#{today}</nsSAFT:AuditFileDateCreated>
        <nsSAFT:SoftwareCompanyName>CyberERP</nsSAFT:SoftwareCompanyName>
        <nsSAFT:SoftwareID>CyberERP</nsSAFT:SoftwareID>
        <nsSAFT:SoftwareVersion>1.0</nsSAFT:SoftwareVersion>
    #{build_company(tenant)}
    #{build_ownership(tenant)}
        <nsSAFT:DefaultCurrencyCode>#{get_currency(tenant)}</nsSAFT:DefaultCurrencyCode>
    #{selection_criteria}
        <nsSAFT:HeaderComment>#{header_comment}</nsSAFT:HeaderComment>
        <nsSAFT:TaxAccountingBasis>#{get_tax_basis(tenant)}</nsSAFT:TaxAccountingBasis>
        <nsSAFT:TaxEntity>#{tenant.name || "Company"}</nsSAFT:TaxEntity>
      </nsSAFT:Header>
    """
  end

  defp build_company(tenant) do
    """
        <nsSAFT:Company>
          <nsSAFT:RegistrationNumber>#{format_eik(tenant.eik)}</nsSAFT:RegistrationNumber>
          <nsSAFT:Name>#{escape_xml(tenant.name)}</nsSAFT:Name>
    #{build_address(tenant)}
    #{build_contact(tenant)}
    #{build_tax_registration(tenant)}
    #{build_bank_account(tenant)}
        </nsSAFT:Company>
    """
  end

  defp build_address(tenant) do
    address = tenant.address || %{}
    street = Map.get(address, :street, Map.get(address, "street", ""))
    number = Map.get(address, :number, Map.get(address, "number", ""))
    city = Map.get(address, :city, Map.get(address, "city", tenant.city || ""))
    postal_code = Map.get(address, :postal_code, Map.get(address, "postal_code", tenant.postal_code || ""))
    country = Map.get(address, :country, Map.get(address, "country", "BG"))

    """
          <nsSAFT:Address>
            <nsSAFT:StreetName>#{escape_xml(street)}</nsSAFT:StreetName>
            <nsSAFT:Number>#{escape_xml(number)}</nsSAFT:Number>
            <nsSAFT:AdditionalAddressDetail/>
            <nsSAFT:Building/>
            <nsSAFT:City>#{escape_xml(city)}</nsSAFT:City>
            <nsSAFT:PostalCode>#{postal_code}</nsSAFT:PostalCode>
            <nsSAFT:Region/>
            <nsSAFT:Country>#{country}</nsSAFT:Country>
            <nsSAFT:AddressType>StreetAddress</nsSAFT:AddressType>
          </nsSAFT:Address>
    """
  end

  defp build_contact(tenant) do
    contact_name = tenant.contact_name || tenant.mol || ""
    contact_phone = tenant.phone || ""
    contact_email = tenant.email || ""

    {first_name, last_name} = split_name(contact_name)

    """
          <nsSAFT:Contact>
            <nsSAFT:ContactPerson>
              <nsSAFT:Title/>
              <nsSAFT:FirstName>#{escape_xml(first_name)}</nsSAFT:FirstName>
              <nsSAFT:Initials/>
              <nsSAFT:LastNamePrefix/>
              <nsSAFT:LastName>#{escape_xml(last_name)}</nsSAFT:LastName>
              <nsSAFT:BirthName/>
              <nsSAFT:Salutation/>
              <nsSAFT:OtherTitles>#{escape_xml(contact_name)}</nsSAFT:OtherTitles>
            </nsSAFT:ContactPerson>
            <nsSAFT:Telephone>#{contact_phone}</nsSAFT:Telephone>
            <nsSAFT:Fax/>
            <nsSAFT:Email>#{contact_email}</nsSAFT:Email>
            <nsSAFT:Website/>
          </nsSAFT:Contact>
    """
  end

  defp build_tax_registration(tenant) do
    eik = format_eik(tenant.eik)
    vat_number = tenant.vat_number || "BG#{String.replace(eik, ~r/^0+/, "")}"
    tax_type = if tenant.is_vat_registered, do: "100010", else: "100020"

    """
          <nsSAFT:TaxRegistration>
            <nsSAFT:TaxRegistrationNumber>#{eik}</nsSAFT:TaxRegistrationNumber>
            <nsSAFT:TaxType>#{tax_type}</nsSAFT:TaxType>
            <nsSAFT:TaxNumber>#{vat_number}</nsSAFT:TaxNumber>
            <nsSAFT:TaxAuthority>NRA</nsSAFT:TaxAuthority>
            <nsSAFT:TaxVerificationDate>#{Date.utc_today() |> Date.to_iso8601()}</nsSAFT:TaxVerificationDate>
          </nsSAFT:TaxRegistration>
    """
  end

  defp build_bank_account(tenant) do
    iban = tenant.iban || ""

    """
        <nsSAFT:BankAccount>
          <nsSAFT:IBANNumber>#{iban}</nsSAFT:IBANNumber>
        </nsSAFT:BankAccount>
    """
  end

  defp build_ownership(tenant) do
    owner_name = tenant.owner_name || tenant.mol || ""
    owner_egn = tenant.owner_egn || ""

    """
        <nsSAFT:Ownership>
          <nsSAFT:IsPartOfGroup>1</nsSAFT:IsPartOfGroup>
          <nsSAFT:BeneficialOwnerNameCyrillicBG>#{escape_xml(owner_name)}</nsSAFT:BeneficialOwnerNameCyrillicBG>
          <nsSAFT:BeneficialOwnerEGN>#{owner_egn}</nsSAFT:BeneficialOwnerEGN>
          <nsSAFT:UltimateOwnerNameCyrillicBG></nsSAFT:UltimateOwnerNameCyrillicBG>
          <nsSAFT:UltimateOwnerUICBG></nsSAFT:UltimateOwnerUICBG>
          <nsSAFT:UltimateOwnerNameCyrillicForeign></nsSAFT:UltimateOwnerNameCyrillicForeign>
          <nsSAFT:UltimateOwnerNameLatinForeign></nsSAFT:UltimateOwnerNameLatinForeign>
          <nsSAFT:CountryForeign>BG</nsSAFT:CountryForeign>
        </nsSAFT:Ownership>
    """
  end

  # Helper functions

  defp format_eik(nil), do: ""
  defp format_eik(eik), do: String.pad_leading(to_string(eik), 12, "0")

  defp get_region(tenant) do
    # BG-01 до BG-28 за областите
    region_code = tenant.region_code || "22"
    "BG-#{region_code}"
  end

  defp get_currency(tenant) do
    tenant.default_currency || "BGN"
  end

  defp get_tax_basis(tenant) do
    # A - търговски предприятия
    # BANK - кредитни институции
    # INSURANCE - застрахователни компании
    # P - бюджетни предприятия
    tenant.tax_basis || "A"
  end

  defp split_name(full_name) when is_binary(full_name) do
    parts = String.split(full_name, " ", trim: true)

    case parts do
      [] -> {"", ""}
      [first] -> {first, ""}
      [first | rest] -> {first, Enum.join(rest, " ")}
    end
  end

  defp split_name(_), do: {"", ""}

  defp escape_xml(nil), do: ""

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape_xml(text), do: escape_xml(to_string(text))
end
