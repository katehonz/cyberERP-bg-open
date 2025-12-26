defmodule CyberCore.SAFT.MasterFiles do
  @moduledoc """
  Генерира MasterFiles секцията на SAF-T файла.

  MasterFiles съдържа:
  - GeneralLedgerAccounts - Сметкоплан
  - Customers - Клиенти
  - Suppliers - Доставчици
  - TaxTable - Данъчна таблица
  - Products - Продукти
  - PhysicalStock - Складови наличности (само за OnDemand)
  - Assets - Активи (само за Annual)
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Accounting.{Account, EntryLine, JournalEntry}
  alias CyberCore.SAFT.Nomenclature.VatTaxType
  alias Decimal, as: D

  @doc """
  Изгражда MasterFiles секцията за даден тип отчет.
  """
  def build(type, tenant_id, opts \\ [])

  def build(:monthly, tenant_id, opts) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)

    content = """
      <nsSAFT:MasterFilesMonthly>
    #{build_general_ledger_accounts(tenant_id, year, month)}
    #{build_customers(tenant_id)}
    #{build_suppliers(tenant_id)}
    #{build_tax_table()}
    #{build_uom_table()}
    #{build_products(tenant_id)}
      </nsSAFT:MasterFilesMonthly>
    """

    {:ok, content}
  end

  def build(:annual, tenant_id, opts) do
    year = Keyword.fetch!(opts, :year)

    content = """
      <nsSAFT:MasterFilesAnnual>
    #{build_assets(tenant_id, year)}
      </nsSAFT:MasterFilesAnnual>
    """

    {:ok, content}
  end

  def build(:on_demand, tenant_id, opts) do
    start_date = Keyword.fetch!(opts, :start_date)
    end_date = Keyword.fetch!(opts, :end_date)

    content = """
      <nsSAFT:MasterFilesOnDemand>
    #{build_products(tenant_id)}
    #{build_physical_stock(tenant_id, start_date, end_date)}
      </nsSAFT:MasterFilesOnDemand>
    """

    {:ok, content}
  end

  # GeneralLedgerAccounts - Сметкоплан (задължителен елемент)
  defp build_general_ledger_accounts(tenant_id, year, month) do
    accounts = get_accounts_with_balances(tenant_id, year, month)

    accounts_xml =
      accounts
      |> Enum.map(&build_account/1)
      |> Enum.join("\n")

    """
      <nsSAFT:GeneralLedgerAccounts>
  #{accounts_xml}
      </nsSAFT:GeneralLedgerAccounts>
    """
  end

  defp build_account(account) do
    """
          <nsSAFT:Account>
            <nsSAFT:AccountID>#{account.code}</nsSAFT:AccountID>
            <nsSAFT:AccountDescription>#{escape_xml(account.name)}</nsSAFT:AccountDescription>
            <nsSAFT:TaxpayerAccountID>#{account.standard_code || account.code}</nsSAFT:TaxpayerAccountID>
            <nsSAFT:AccountType>#{account_type(account)}</nsSAFT:AccountType>
            <nsSAFT:AccountCreationDate>#{format_date(account.inserted_at)}</nsSAFT:AccountCreationDate>
    #{format_balance(account)}
          </nsSAFT:Account>
    """
  end

  defp account_type(account) do
    case account.account_type do
      "debit" -> "Debit"
      "credit" -> "Credit"
      _ -> "Bifunctional"
    end
  end

  defp format_balance(account) do
    opening_debit = D.to_string(account.opening_debit || D.new(0))
    opening_credit = D.to_string(account.opening_credit || D.new(0))
    closing_debit = D.to_string(account.closing_debit || D.new(0))
    closing_credit = D.to_string(account.closing_credit || D.new(0))

    cond do
      D.gt?(account.opening_debit || D.new(0), D.new(0)) or
          D.gt?(account.closing_debit || D.new(0), D.new(0)) ->
        """
            <nsSAFT:OpeningDebitBalance>#{opening_debit}</nsSAFT:OpeningDebitBalance>
            <nsSAFT:ClosingDebitBalance>#{closing_debit}</nsSAFT:ClosingDebitBalance>
        """

      true ->
        """
            <nsSAFT:OpeningCreditBalance>#{opening_credit}</nsSAFT:OpeningCreditBalance>
            <nsSAFT:ClosingCreditBalance>#{closing_credit}</nsSAFT:ClosingCreditBalance>
        """
    end
  end

  # Customers - Клиенти (задължителен елемент)
  defp build_customers(tenant_id) do
    customers = get_customers(tenant_id)

    customers_xml =
      customers
      |> Enum.map(&build_customer/1)
      |> Enum.join("\n")

    """
      <nsSAFT:Customers>
  #{customers_xml}
      </nsSAFT:Customers>
    """
  end

  defp build_customer(customer) do
    opening_balance = customer.opening_debit_balance || D.new(0)
    closing_balance = customer.closing_debit_balance || D.new(0)

    """
          <nsSAFT:Customer>
    #{build_company_structure(customer)}
            <nsSAFT:CustomerID>#{customer.registration_number || customer.id}</nsSAFT:CustomerID>
            <nsSAFT:SelfBillingIndicator>#{if customer.self_billing_indicator, do: "Y", else: "N"}</nsSAFT:SelfBillingIndicator>
            <nsSAFT:AccountID>411</nsSAFT:AccountID>
            <nsSAFT:OpeningDebitBalance>#{format_decimal(opening_balance)}</nsSAFT:OpeningDebitBalance>
            <nsSAFT:ClosingDebitBalance>#{format_decimal(closing_balance)}</nsSAFT:ClosingDebitBalance>
          </nsSAFT:Customer>
    """
  end

  # Suppliers - Доставчици (задължителен елемент)
  defp build_suppliers(tenant_id) do
    suppliers = get_suppliers(tenant_id)

    suppliers_xml =
      suppliers
      |> Enum.map(&build_supplier/1)
      |> Enum.join("\n")

    """
      <nsSAFT:Suppliers>
  #{suppliers_xml}
      </nsSAFT:Suppliers>
    """
  end

  defp build_supplier(supplier) do
    opening_balance = supplier.opening_credit_balance || D.new(0)
    closing_balance = supplier.closing_credit_balance || D.new(0)

    """
          <nsSAFT:Supplier>
    #{build_company_structure(supplier)}
            <nsSAFT:SupplierID>#{supplier.registration_number || supplier.id}</nsSAFT:SupplierID>
            <nsSAFT:SelfBillingIndicator>#{if supplier.self_billing_indicator, do: "Y", else: "N"}</nsSAFT:SelfBillingIndicator>
            <nsSAFT:AccountID>401</nsSAFT:AccountID>
            <nsSAFT:OpeningCreditBalance>#{format_decimal(opening_balance)}</nsSAFT:OpeningCreditBalance>
            <nsSAFT:ClosingCreditBalance>#{format_decimal(closing_balance)}</nsSAFT:ClosingCreditBalance>
          </nsSAFT:Supplier>
    """
  end

  # CompanyStructure - обща структура за Customer и Supplier
  defp build_company_structure(contact) do
    city = contact.city || "София"
    country = contact.country || "BG"
    street = contact.street_name || contact.address || ""
    postal_code = contact.postal_code || ""
    building_number = contact.building_number || ""
    related_party = if contact.related_party, do: "Y", else: "N"
    eik = contact.registration_number || ""
    vat_number = contact.vat_number || ""

    tax_registration =
      if eik != "" or vat_number != "" do
        tax_type = VatTaxType.from_vat_status(vat_number != "")

        """
              <nsSAFT:TaxRegistration>
                <nsSAFT:TaxRegistrationNumber>#{format_eik(eik)}</nsSAFT:TaxRegistrationNumber>
                <nsSAFT:TaxType>#{tax_type}</nsSAFT:TaxType>
                <nsSAFT:TaxNumber>#{vat_number}</nsSAFT:TaxNumber>
              </nsSAFT:TaxRegistration>
        """
      else
        ""
      end

    bank_account =
      if contact.iban_number do
        """
              <nsSAFT:BankAccount>
                <nsSAFT:IBANNumber>#{contact.iban_number}</nsSAFT:IBANNumber>
              </nsSAFT:BankAccount>
        """
      else
        ""
      end

    """
            <nsSAFT:CompanyStructure>
              <nsSAFT:RegistrationNumber>#{format_eik(eik)}</nsSAFT:RegistrationNumber>
              <nsSAFT:Name>#{escape_xml(contact.name)}</nsSAFT:Name>
              <nsSAFT:Address>
                <nsSAFT:StreetName>#{escape_xml(street)}</nsSAFT:StreetName>
                <nsSAFT:Number>#{building_number}</nsSAFT:Number>
                <nsSAFT:City>#{escape_xml(city)}</nsSAFT:City>
                <nsSAFT:PostalCode>#{postal_code}</nsSAFT:PostalCode>
                <nsSAFT:Country>#{country}</nsSAFT:Country>
                <nsSAFT:AddressType>StreetAddress</nsSAFT:AddressType>
              </nsSAFT:Address>
    #{tax_registration}#{bank_account}          <nsSAFT:RelatedParty>#{related_party}</nsSAFT:RelatedParty>
            </nsSAFT:CompanyStructure>
    """
  end

  # TaxTable - Данъчна таблица
  defp build_tax_table do
    """
        <nsSAFT:TaxTable>
          <nsSAFT:TaxTableEntry>
            <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
            <nsSAFT:Description>ДДС 20%</nsSAFT:Description>
            <nsSAFT:TaxCodeDetails>
              <nsSAFT:TaxCode>20</nsSAFT:TaxCode>
              <nsSAFT:Description>Стандартна ставка</nsSAFT:Description>
              <nsSAFT:TaxPercentage>20.00</nsSAFT:TaxPercentage>
              <nsSAFT:Country>BG</nsSAFT:Country>
            </nsSAFT:TaxCodeDetails>
          </nsSAFT:TaxTableEntry>
          <nsSAFT:TaxTableEntry>
            <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
            <nsSAFT:Description>ДДС 9%</nsSAFT:Description>
            <nsSAFT:TaxCodeDetails>
              <nsSAFT:TaxCode>9</nsSAFT:TaxCode>
              <nsSAFT:Description>Намалена ставка</nsSAFT:Description>
              <nsSAFT:TaxPercentage>9.00</nsSAFT:TaxPercentage>
              <nsSAFT:Country>BG</nsSAFT:Country>
            </nsSAFT:TaxCodeDetails>
          </nsSAFT:TaxTableEntry>
          <nsSAFT:TaxTableEntry>
            <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
            <nsSAFT:Description>ДДС 0%</nsSAFT:Description>
            <nsSAFT:TaxCodeDetails>
              <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
              <nsSAFT:Description>Нулева ставка</nsSAFT:Description>
              <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
              <nsSAFT:Country>BG</nsSAFT:Country>
            </nsSAFT:TaxCodeDetails>
          </nsSAFT:TaxTableEntry>
        </nsSAFT:TaxTable>
    """
  end

  defp build_uom_table do
    """
    <nsSAFT:UOMTable>
        <nsSAFT:UOMTableEntry>
            <nsSAFT:UnitOfMeasure>PCE</nsSAFT:UnitOfMeasure>
            <nsSAFT:Description>Брой</nsSAFT:Description>
        </nsSAFT:UOMTableEntry>
        <nsSAFT:UOMTableEntry>
            <nsSAFT:UnitOfMeasure>KGM</nsSAFT:UnitOfMeasure>
            <nsSAFT:Description>Килограм</nsSAFT:Description>
        </nsSAFT:UOMTableEntry>
        <nsSAFT:UOMTableEntry>
            <nsSAFT:UnitOfMeasure>MTR</nsSAFT:UnitOfMeasure>
            <nsSAFT:Description>Метър</nsSAFT:Description>
        </nsSAFT:UOMTableEntry>
        <nsSAFT:UOMTableEntry>
            <nsSAFT:UnitOfMeasure>LTR</nsSAFT:UnitOfMeasure>
            <nsSAFT:Description>Литър</nsSAFT:Description>
        </nsSAFT:UOMTableEntry>
    </nsSAFT:UOMTable>
    """
  end


  # Products - Продукти (задължителен елемент)
  defp build_products(tenant_id) do
    products = get_products(tenant_id)

    products_xml =
      products
      |> Enum.map(&build_product/1)
      |> Enum.join("\n")

    """
      <nsSAFT:Products>
  #{products_xml}
      </nsSAFT:Products>
    """
  end

  defp build_product(product) do
    cn_code = get_cn_code(product)
    # GoodsServicesID: G = Goods, S = Services
    goods_services_id = if product.category == "service", do: "S", else: "G"

    """
          <nsSAFT:Product>
            <nsSAFT:ProductCode>#{product.sku || product.id}</nsSAFT:ProductCode>
            <nsSAFT:GoodsServicesID>#{goods_services_id}</nsSAFT:GoodsServicesID>
            <nsSAFT:ProductGroup>#{escape_xml(product.category || "")}</nsSAFT:ProductGroup>
            <nsSAFT:Description>#{escape_xml(product.name)}</nsSAFT:Description>
            <nsSAFT:ProductCommodityCode>#{cn_code}</nsSAFT:ProductCommodityCode>
            <nsSAFT:UOMBase>#{product.unit || "PCE"}</nsSAFT:UOMBase>
            <nsSAFT:UOMStandard>#{product.unit || "PCE"}</nsSAFT:UOMStandard>
            <nsSAFT:UOMToUOMBaseConversionFactor>1.00</nsSAFT:UOMToUOMBaseConversionFactor>
          </nsSAFT:Product>
    """
  end

  defp get_cn_code(product) do
    cond do
      product.cn_code && product.cn_code.code -> product.cn_code.code
      product.cn_code_id -> ""
      true -> ""
    end
  end

  # PhysicalStock - Складови наличности (за OnDemand)
  defp build_physical_stock(tenant_id, start_date, end_date) do
    stock_items = get_physical_stock(tenant_id, start_date, end_date)

    if Enum.empty?(stock_items) do
      ""
    else
      stock_xml =
        stock_items
        |> Enum.map(&build_stock_item/1)
        |> Enum.join("\n")

      """
        <nsSAFT:PhysicalStock>
    #{stock_xml}
        </nsSAFT:PhysicalStock>
      """
    end
  end

  defp build_stock_item(item) do
    """
          <nsSAFT:PhysicalStockEntry>
            <nsSAFT:WarehouseID>#{item.warehouse_id}</nsSAFT:WarehouseID>
            <nsSAFT:ProductCode>#{item.product_code}</nsSAFT:ProductCode>
            <nsSAFT:StockAccountID>#{item.account_id || "302"}</nsSAFT:StockAccountID>
            <nsSAFT:Quantity>#{D.to_string(item.quantity)}</nsSAFT:Quantity>
            <nsSAFT:UOMPhysicalStock>#{item.unit || "PCE"}</nsSAFT:UOMPhysicalStock>
            <nsSAFT:UnitPrice>#{format_decimal(item.unit_price)}</nsSAFT:UnitPrice>
            <nsSAFT:StockValue>#{format_decimal(item.stock_value)}</nsSAFT:StockValue>
          </nsSAFT:PhysicalStockEntry>
    """
  end

  # Assets - Активи (за Annual)
  defp build_assets(tenant_id, year) do
    assets = get_assets(tenant_id, year)

    if Enum.empty?(assets) do
      ""
    else
      assets_xml =
        assets
        |> Enum.map(&build_asset/1)
        |> Enum.join("\n")

      """
        <nsSAFT:Assets>
    #{assets_xml}
        </nsSAFT:Assets>
      """
    end
  end

  defp build_asset(asset) do
    """
          <nsSAFT:Asset>
            <nsSAFT:AssetID>#{asset.code}</nsSAFT:AssetID>
            <nsSAFT:AccountID>#{asset.account_code || "205"}</nsSAFT:AccountID>
            <nsSAFT:Description>#{escape_xml(asset.name)}</nsSAFT:Description>
    #{build_asset_supplier(asset)}
            <nsSAFT:PurchaseOrderDate>#{format_date(asset.purchase_order_date || asset.acquisition_date)}</nsSAFT:PurchaseOrderDate>
            <nsSAFT:DateOfAcquisition>#{format_date(asset.acquisition_date)}</nsSAFT:DateOfAcquisition>
            <nsSAFT:StartUpDate>#{format_date(asset.startup_date || asset.acquisition_date)}</nsSAFT:StartUpDate>
    #{build_asset_valuations(asset)}
          </nsSAFT:Asset>
    """
  end

  defp build_asset_supplier(asset) do
    if asset.supplier do
      """
            <nsSAFT:AssetSupplier>
              <nsSAFT:SupplierName>#{escape_xml(asset.supplier.name)}</nsSAFT:SupplierName>
              <nsSAFT:SupplierID>#{asset.supplier.vat_number || asset.supplier.eik || ""}</nsSAFT:SupplierID>
              <nsSAFT:PostalAddress>
                <nsSAFT:City>#{escape_xml(asset.supplier.city || "")}</nsSAFT:City>
                <nsSAFT:Country>#{asset.supplier.country || "BG"}</nsSAFT:Country>
              </nsSAFT:PostalAddress>
            </nsSAFT:AssetSupplier>
      """
    else
      ""
    end
  end

  defp build_asset_valuations(asset) do
    """
            <nsSAFT:Valuations>
              <nsSAFT:ValuationSAP>
                <nsSAFT:ValuationClass>#{asset.account_code || "205"}</nsSAFT:ValuationClass>
                <nsSAFT:AcquisitionAndProductionCostsBegin>#{format_decimal(asset.acquisition_cost_begin_year || asset.acquisition_cost)}</nsSAFT:AcquisitionAndProductionCostsBegin>
                <nsSAFT:AcquisitionAndProductionCostsEnd>#{format_decimal(asset.acquisition_cost)}</nsSAFT:AcquisitionAndProductionCostsEnd>
                <nsSAFT:InvestmentSupport>0.00</nsSAFT:InvestmentSupport>
                <nsSAFT:AssetLifeYear>#{asset.useful_life_months && div(asset.useful_life_months, 12) || 5}</nsSAFT:AssetLifeYear>
                <nsSAFT:AssetAddition>0.00</nsSAFT:AssetAddition>
                <nsSAFT:Transfers>0.00</nsSAFT:Transfers>
                <nsSAFT:AssetDisposal>0.00</nsSAFT:AssetDisposal>
                <nsSAFT:BookValueBegin>#{format_decimal(asset.book_value_begin_year || asset.acquisition_cost)}</nsSAFT:BookValueBegin>
                <nsSAFT:DepreciationMethod>#{asset.depreciation_method || "Линеен"}</nsSAFT:DepreciationMethod>
                <nsSAFT:DepreciationPercentage>#{calculate_depreciation_rate(asset)}</nsSAFT:DepreciationPercentage>
                <nsSAFT:DepreciationForPeriod>#{format_decimal(asset.depreciation_for_period || D.new(0))}</nsSAFT:DepreciationForPeriod>
                <nsSAFT:AppreciationForPeriod>0.00</nsSAFT:AppreciationForPeriod>
                <nsSAFT:AccumulatedDepreciation>#{format_decimal(asset.accumulated_depreciation || D.new(0))}</nsSAFT:AccumulatedDepreciation>
                <nsSAFT:BookValueEnd>#{format_decimal(asset.book_value || asset.acquisition_cost)}</nsSAFT:BookValueEnd>
              </nsSAFT:ValuationSAP>
              <nsSAFT:ValuationDAP>
                <nsSAFT:ValuationClass>#{asset.tax_category || "V"}</nsSAFT:ValuationClass>
                <nsSAFT:CategoryTaxDepreciable>ДМА</nsSAFT:CategoryTaxDepreciable>
                <nsSAFT:TaxDepreciableValue>#{format_decimal(asset.acquisition_cost)}</nsSAFT:TaxDepreciableValue>
                <nsSAFT:AccruedTaxDepreciation>#{format_decimal(asset.accumulated_depreciation || D.new(0))}</nsSAFT:AccruedTaxDepreciation>
                <nsSAFT:TaxValueAsset>#{format_decimal(asset.book_value || asset.acquisition_cost)}</nsSAFT:TaxValueAsset>
                <nsSAFT:AnnualTaxDepreciationRate>#{calculate_tax_depreciation_rate(asset)}</nsSAFT:AnnualTaxDepreciationRate>
                <nsSAFT:MonthChangeAssetValue>#{asset.month_value_change || 0}</nsSAFT:MonthChangeAssetValue>
                <nsSAFT:MonthSuspensionResumptionAccrual>#{asset.month_suspension_resumption || 0}</nsSAFT:MonthSuspensionResumptionAccrual>
                <nsSAFT:MonthWriteOffAccounting>#{asset.month_writeoff_accounting || 0}</nsSAFT:MonthWriteOffAccounting>
                <nsSAFT:MonthWriteOffTax>#{asset.month_writeoff_tax || 0}</nsSAFT:MonthWriteOffTax>
                <nsSAFT:NumberMonthsDepreciationDuring>#{asset.depreciation_months_current_year || 12}</nsSAFT:NumberMonthsDepreciationDuring>
                <nsSAFT:DepreciationForPeriod>#{format_decimal(asset.depreciation_for_period || D.new(0))}</nsSAFT:DepreciationForPeriod>
                <nsSAFT:AccumulatedDepreciation>#{format_decimal(asset.accumulated_depreciation || D.new(0))}</nsSAFT:AccumulatedDepreciation>
                <nsSAFT:TaxValueEndPeriod>#{format_decimal(asset.book_value || asset.acquisition_cost)}</nsSAFT:TaxValueEndPeriod>
              </nsSAFT:ValuationDAP>
            </nsSAFT:Valuations>
    """
  end

  defp calculate_depreciation_rate(asset) do
    if asset.useful_life_months && asset.useful_life_months > 0 do
      Float.round(12 / asset.useful_life_months * 100, 2)
    else
      20.0
    end
  end

  defp calculate_tax_depreciation_rate(asset) do
    # Данъчни норми по ЗКПО
    case asset.tax_category do
      "I" -> 4      # Масивни сгради
      "II" -> 30    # Машини и оборудване
      "III" -> 10   # Превозни средства (без автомобили)
      "IV" -> 50    # Компютри, софтуер
      "V" -> 25     # Автомобили
      "VI" -> 15    # ДНА, права
      "VII" -> 100  # Нискостойностни активи
      _ -> 20       # По подразбиране
    end
  end

  # Database queries

  defp get_accounts_with_balances(tenant_id, year, month) do
    accounts =
      from(a in Account, where: a.tenant_id == ^tenant_id and a.is_active == true, order_by: a.code)
      |> Repo.all()

    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    Enum.map(accounts, fn account ->
      # Използване на зададеното начално салдо вместо изчисленото
      opening_balance = account.opening_balance || calculate_opening_balance(account.id, start_date)
      
      {debit_turnover, credit_turnover} = calculate_turnover(account.id, start_date, end_date)

      closing_balance =
        if Account.debit_account?(account) do
          D.add(D.sub(opening_balance, credit_turnover), debit_turnover)
        else
          D.add(D.sub(opening_balance, debit_turnover), credit_turnover)
        end

      {opening_debit, opening_credit} = split_balance(opening_balance, account)
      {closing_debit, closing_credit} = split_balance(closing_balance, account)

      Map.merge(account, %{
        opening_debit: opening_debit,
        opening_credit: opening_credit,
        closing_debit: closing_debit,
        closing_credit: closing_credit
      })
    end)
  end

  defp get_customers(tenant_id) do
    try do
      from(c in CyberCore.Contacts.Contact,
        where: c.tenant_id == ^tenant_id and c.is_customer == true,
        order_by: c.name
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_suppliers(tenant_id) do
    try do
      from(c in CyberCore.Contacts.Contact,
        where: c.tenant_id == ^tenant_id and c.is_supplier == true,
        order_by: c.name
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_products(tenant_id) do
    try do
      from(p in CyberCore.Inventory.Product,
        where: p.tenant_id == ^tenant_id and p.is_active == true,
        preload: [:cn_code],
        order_by: p.name
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_physical_stock(tenant_id, _start_date, _end_date) do
    try do
      from(sl in CyberCore.Inventory.StockLevel,
        join: p in CyberCore.Inventory.Product,
        on: sl.product_id == p.id,
        join: w in CyberCore.Inventory.Warehouse,
        on: sl.warehouse_id == w.id,
        where: sl.tenant_id == ^tenant_id and sl.quantity > 0,
        select: %{
          warehouse_id: w.code,
          product_code: p.code,
          account_id: "302",
          quantity: sl.quantity,
          unit: p.unit,
          unit_price: sl.average_cost,
          stock_value: fragment("? * ?", sl.quantity, sl.average_cost)
        }
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_assets(tenant_id, _year) do
    try do
      from(a in CyberCore.Accounting.Asset,
        where: a.tenant_id == ^tenant_id and a.status == "active",
        preload: [:supplier],
        order_by: a.code
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  # Balance Calculation Helpers (adapted from CyberCore.Accounting)

  defp calculate_opening_balance(account, from_date) do
    initial_balance = account.initial_balance || D.new(0)

    {debit_total, credit_total} =
      calculate_turnover(account.id, ~D[1970-01-01], Date.add(from_date, -1))

    opening = D.add(initial_balance, D.sub(debit_total, credit_total))

    if Account.debit_account?(account) do
      opening
    else
      D.mult(opening, -1)
    end
  end

  defp calculate_turnover(account_id, from_date, to_date) do
    query =
      from l in EntryLine,
        join: j in JournalEntry,
        on: l.journal_entry_id == j.id,
        where: l.account_id == ^account_id,
        where: j.is_posted == true,
        where: j.accounting_date >= ^from_date,
        where: j.accounting_date <= ^to_date,
        select: {sum(l.debit_amount), sum(l.credit_amount)}

    case Repo.one(query) do
      {nil, nil} -> {D.new(0), D.new(0)}
      {debit, nil} -> {debit, D.new(0)}
      {nil, credit} -> {D.new(0), credit}
      {debit, credit} -> {debit, credit}
    end
  end

  defp split_balance(balance, account) do
    is_debit_acc = Account.debit_account?(account)

    cond do
      is_debit_acc and D.gt?(balance, 0) -> {balance, D.new(0)}
      is_debit_acc -> {D.new(0), D.mult(balance, -1)}
      not is_debit_acc and D.gt?(balance, 0) -> {D.new(0), balance}
      not is_debit_acc -> {D.mult(balance, -1), D.new(0)}
    end
  end

  # Helper functions

  defp format_eik(nil), do: ""
  defp format_eik(eik), do: String.pad_leading(to_string(eik), 12, "0")

  defp format_date(nil), do: Date.utc_today() |> Date.to_iso8601()
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt) |> Date.to_iso8601()
  defp format_date(date), do: to_string(date)

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(%D{} = d), do: D.round(d, 2) |> D.to_string()
  defp format_decimal(n) when is_number(n), do: :erlang.float_to_binary(n / 1, decimals: 2)
  defp format_decimal(s), do: to_string(s)

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
