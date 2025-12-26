defmodule CyberCore.SAFT.SourceDocuments do
  @moduledoc """
  Генерира SourceDocuments секцията на SAF-T файла.

  За Monthly:
  - SalesInvoices - Фактури за продажба
  - PurchaseInvoices - Фактури за покупка
  - Payments - Плащания

  За OnDemand:
  - MovementOfGoods - Движения на стоки

  За Annual:
  - AssetTransactions - Транзакции с активи
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.SAFT.Nomenclature.{StockMovementType, AssetMovementType}

  @doc """
  Изгражда SourceDocuments секцията за даден тип отчет.
  """
  def build(type, tenant_id, opts \\ [])

  def build(:monthly, tenant_id, opts) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)

    # XSD order: SalesInvoices -> Payments -> PurchaseInvoices
    content = """
      <nsSAFT:SourceDocumentsMonthly>
    #{build_sales_invoices(tenant_id, year, month)}
    #{build_payments(tenant_id, year, month)}
    #{build_purchase_invoices(tenant_id, year, month)}
      </nsSAFT:SourceDocumentsMonthly>
    """

    {:ok, content}
  end

  def build(:annual, tenant_id, opts) do
    year = Keyword.fetch!(opts, :year)

    content = """
      <nsSAFT:SourceDocumentsAnnual>
    #{build_asset_transactions(tenant_id, year)}
      </nsSAFT:SourceDocumentsAnnual>
    """

    {:ok, content}
  end

  def build(:on_demand, tenant_id, opts) do
    start_date = Keyword.fetch!(opts, :start_date)
    end_date = Keyword.fetch!(opts, :end_date)

    content = """
      <nsSAFT:SourceDocumentsOnDemand>
    #{build_movement_of_goods(tenant_id, start_date, end_date)}
      </nsSAFT:SourceDocumentsOnDemand>
    """

    {:ok, content}
  end

  # SalesInvoices - Фактури за продажба
  defp build_sales_invoices(tenant_id, year, month) do
    invoices = get_sales_invoices(tenant_id, year, month)
    {total_debit, total_credit} = calculate_invoice_totals(invoices)

    invoices_xml =
      if Enum.empty?(invoices) do
        # Placeholder invoice когато няма фактури
        build_placeholder_sales_invoice(year, month)
      else
        invoices
        |> Enum.map(&build_sales_invoice/1)
        |> Enum.join("\n")
      end

    """
      <nsSAFT:SalesInvoices>
        <nsSAFT:NumberOfEntries>#{length(invoices)}</nsSAFT:NumberOfEntries>
        <nsSAFT:TotalDebit>#{format_decimal(total_debit)}</nsSAFT:TotalDebit>
        <nsSAFT:TotalCredit>#{format_decimal(total_credit)}</nsSAFT:TotalCredit>
  #{invoices_xml}
      </nsSAFT:SalesInvoices>
    """
  end

  defp build_placeholder_sales_invoice(year, month) do
    date = Date.new!(year, month, 1)
    """
          <nsSAFT:Invoice>
            <nsSAFT:InvoiceNo>0000000000</nsSAFT:InvoiceNo>
            <nsSAFT:CustomerInfo>
              <nsSAFT:CustomerID></nsSAFT:CustomerID>
              <nsSAFT:Name>Няма фактури за периода</nsSAFT:Name>
              <nsSAFT:BillingAddress>
                <nsSAFT:City>София</nsSAFT:City>
                <nsSAFT:Country>BG</nsSAFT:Country>
              </nsSAFT:BillingAddress>
            </nsSAFT:CustomerInfo>
            <nsSAFT:AccountID>411</nsSAFT:AccountID>
            <nsSAFT:InvoiceDate>#{Date.to_iso8601(date)}</nsSAFT:InvoiceDate>
            <nsSAFT:InvoiceType>01</nsSAFT:InvoiceType>
            <nsSAFT:SelfBillingIndicator>N</nsSAFT:SelfBillingIndicator>
            <nsSAFT:TransactionID></nsSAFT:TransactionID>
            <nsSAFT:InvoiceLine>
              <nsSAFT:LineNumber>1</nsSAFT:LineNumber>
              <nsSAFT:AccountID>411</nsSAFT:AccountID>
              <nsSAFT:ProductCode></nsSAFT:ProductCode>
              <nsSAFT:ProductDescription>Няма данни</nsSAFT:ProductDescription>
              <nsSAFT:Quantity>0</nsSAFT:Quantity>
              <nsSAFT:InvoiceUOM>PCE</nsSAFT:InvoiceUOM>
              <nsSAFT:UnitPrice>0.00</nsSAFT:UnitPrice>
              <nsSAFT:TaxPointDate>#{Date.to_iso8601(date)}</nsSAFT:TaxPointDate>
              <nsSAFT:Description></nsSAFT:Description>
              <nsSAFT:InvoiceLineAmount>
                <nsSAFT:Amount>0.00</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
              </nsSAFT:InvoiceLineAmount>
              <nsSAFT:DebitCreditIndicator>C</nsSAFT:DebitCreditIndicator>
              <nsSAFT:TaxInformation>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>0.00</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>0.00</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformation>
            </nsSAFT:InvoiceLine>
            <nsSAFT:InvoiceDocumentTotals>
              <nsSAFT:TaxInformationTotals>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>0.00</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>0.00</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformationTotals>
              <nsSAFT:NetTotal>0.00</nsSAFT:NetTotal>
              <nsSAFT:GrossTotal>0.00</nsSAFT:GrossTotal>
            </nsSAFT:InvoiceDocumentTotals>
          </nsSAFT:Invoice>
    """
  end

  defp build_sales_invoice(invoice) do
    lines_xml =
      invoice.lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, idx} -> build_invoice_line(line, idx) end)
      |> Enum.join("\n")

    """
          <nsSAFT:Invoice>
            <nsSAFT:InvoiceNo>#{invoice.number}</nsSAFT:InvoiceNo>
            <nsSAFT:CustomerInfo>
              <nsSAFT:CustomerID>#{invoice.customer_id || ""}</nsSAFT:CustomerID>
              <nsSAFT:Name>#{escape_xml(invoice.customer_name || "")}</nsSAFT:Name>
    #{build_invoice_customer_address(invoice)}
            </nsSAFT:CustomerInfo>
            <nsSAFT:AccountID>411</nsSAFT:AccountID>
            <nsSAFT:Period>#{invoice.date.month}</nsSAFT:Period>
            <nsSAFT:PeriodYear>#{invoice.date.year}</nsSAFT:PeriodYear>
            <nsSAFT:InvoiceDate>#{format_date(invoice.date)}</nsSAFT:InvoiceDate>
            <nsSAFT:InvoiceType>#{invoice.invoice_type || "01"}</nsSAFT:InvoiceType>
            <nsSAFT:SelfBillingIndicator>N</nsSAFT:SelfBillingIndicator>
            <nsSAFT:SourceID>#{invoice.created_by || "system"}</nsSAFT:SourceID>
            <nsSAFT:GLPostingDate>#{format_date(invoice.posted_at || invoice.date)}</nsSAFT:GLPostingDate>
            <nsSAFT:TransactionID>#{invoice.journal_entry_id || ""}</nsSAFT:TransactionID>
    #{lines_xml}
            <nsSAFT:InvoiceDocumentTotals>
              <nsSAFT:TaxInformationTotals>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>#{invoice.vat_rate || "20"}</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>#{format_decimal(invoice.vat_rate || Decimal.new(20))}</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>#{format_decimal(invoice.subtotal)}</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>#{format_decimal(invoice.vat_amount)}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{invoice.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(invoice.vat_amount)}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformationTotals>
              <nsSAFT:NetTotal>#{format_decimal(invoice.subtotal)}</nsSAFT:NetTotal>
              <nsSAFT:GrossTotal>#{format_decimal(invoice.total)}</nsSAFT:GrossTotal>
            </nsSAFT:InvoiceDocumentTotals>
          </nsSAFT:Invoice>
    """
  end

  defp build_invoice_customer_address(invoice) do
    """
              <nsSAFT:BillingAddress>
                <nsSAFT:StreetName>#{escape_xml(invoice.customer_address || "")}</nsSAFT:StreetName>
                <nsSAFT:City>#{escape_xml(invoice.customer_city || "")}</nsSAFT:City>
                <nsSAFT:PostalCode>#{invoice.customer_postal_code || ""}</nsSAFT:PostalCode>
                <nsSAFT:Country>#{invoice.customer_country || "BG"}</nsSAFT:Country>
              </nsSAFT:BillingAddress>
    """
  end

  defp build_invoice_line(line, index) do
    """
            <nsSAFT:InvoiceLine>
              <nsSAFT:LineNumber>#{index}</nsSAFT:LineNumber>
              <nsSAFT:AccountID>#{line.account_code || "411"}</nsSAFT:AccountID>
              <nsSAFT:ProductCode>#{line.product_code || ""}</nsSAFT:ProductCode>
              <nsSAFT:ProductDescription>#{escape_xml(line.description || line.product_name || "")}</nsSAFT:ProductDescription>
              <nsSAFT:Quantity>#{format_decimal(line.quantity)}</nsSAFT:Quantity>
              <nsSAFT:InvoiceUOM>#{line.unit || "PCE"}</nsSAFT:InvoiceUOM>
              <nsSAFT:UnitPrice>#{format_decimal(line.unit_price)}</nsSAFT:UnitPrice>
              <nsSAFT:TaxPointDate>#{format_date(line.date || Date.utc_today())}</nsSAFT:TaxPointDate>
              <nsSAFT:Description>#{escape_xml(line.description || "")}</nsSAFT:Description>
              <nsSAFT:InvoiceLineAmount>
                <nsSAFT:Amount>#{format_decimal(line.amount)}</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>#{format_decimal(line.amount)}</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
              </nsSAFT:InvoiceLineAmount>
              <nsSAFT:DebitCreditIndicator>C</nsSAFT:DebitCreditIndicator>
              <nsSAFT:TaxInformation>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>#{line.vat_rate || "20"}</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>#{format_decimal(line.vat_rate || Decimal.new(20))}</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>#{format_decimal(line.amount)}</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>#{format_decimal(line.vat_amount || Decimal.new(0))}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(line.vat_amount || Decimal.new(0))}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformation>
            </nsSAFT:InvoiceLine>
    """
  end

  # PurchaseInvoices - Фактури за покупка
  defp build_purchase_invoices(tenant_id, year, month) do
    invoices = get_purchase_invoices(tenant_id, year, month)
    {total_debit, total_credit} = calculate_invoice_totals(invoices)

    invoices_xml =
      if Enum.empty?(invoices) do
        build_placeholder_purchase_invoice(year, month)
      else
        invoices
        |> Enum.map(&build_purchase_invoice/1)
        |> Enum.join("\n")
      end

    """
      <nsSAFT:PurchaseInvoices>
        <nsSAFT:NumberOfEntries>#{length(invoices)}</nsSAFT:NumberOfEntries>
        <nsSAFT:TotalDebit>#{format_decimal(total_debit)}</nsSAFT:TotalDebit>
        <nsSAFT:TotalCredit>#{format_decimal(total_credit)}</nsSAFT:TotalCredit>
  #{invoices_xml}
      </nsSAFT:PurchaseInvoices>
    """
  end

  defp build_placeholder_purchase_invoice(year, month) do
    date = Date.new!(year, month, 1)
    """
          <nsSAFT:Invoice>
            <nsSAFT:InvoiceNo>0000000000</nsSAFT:InvoiceNo>
            <nsSAFT:SupplierInfo>
              <nsSAFT:SupplierID></nsSAFT:SupplierID>
              <nsSAFT:Name>Няма фактури за периода</nsSAFT:Name>
              <nsSAFT:BillingAddress>
                <nsSAFT:City>София</nsSAFT:City>
                <nsSAFT:Country>BG</nsSAFT:Country>
              </nsSAFT:BillingAddress>
            </nsSAFT:SupplierInfo>
            <nsSAFT:AccountID>401</nsSAFT:AccountID>
            <nsSAFT:InvoiceDate>#{Date.to_iso8601(date)}</nsSAFT:InvoiceDate>
            <nsSAFT:InvoiceType>01</nsSAFT:InvoiceType>
            <nsSAFT:SelfBillingIndicator>N</nsSAFT:SelfBillingIndicator>
            <nsSAFT:TransactionID></nsSAFT:TransactionID>
            <nsSAFT:InvoiceLine>
              <nsSAFT:LineNumber>1</nsSAFT:LineNumber>
              <nsSAFT:AccountID>401</nsSAFT:AccountID>
              <nsSAFT:ProductCode></nsSAFT:ProductCode>
              <nsSAFT:ProductDescription>Няма данни</nsSAFT:ProductDescription>
              <nsSAFT:Quantity>0</nsSAFT:Quantity>
              <nsSAFT:InvoiceUOM>PCE</nsSAFT:InvoiceUOM>
              <nsSAFT:UnitPrice>0.00</nsSAFT:UnitPrice>
              <nsSAFT:TaxPointDate>#{Date.to_iso8601(date)}</nsSAFT:TaxPointDate>
              <nsSAFT:Description></nsSAFT:Description>
              <nsSAFT:InvoiceLineAmount>
                <nsSAFT:Amount>0.00</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
              </nsSAFT:InvoiceLineAmount>
              <nsSAFT:DebitCreditIndicator>D</nsSAFT:DebitCreditIndicator>
              <nsSAFT:TaxInformation>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>0.00</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>0.00</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformation>
            </nsSAFT:InvoiceLine>
            <nsSAFT:InvoiceDocumentTotals>
              <nsSAFT:TaxInformationTotals>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>0</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>0.00</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>0.00</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>0.00</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformationTotals>
              <nsSAFT:NetTotal>0.00</nsSAFT:NetTotal>
              <nsSAFT:GrossTotal>0.00</nsSAFT:GrossTotal>
            </nsSAFT:InvoiceDocumentTotals>
          </nsSAFT:Invoice>
    """
  end

  defp build_purchase_invoice(invoice) do
    lines_xml =
      invoice.lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, idx} -> build_purchase_invoice_line(line, idx) end)
      |> Enum.join("\n")

    """
          <nsSAFT:Invoice>
            <nsSAFT:InvoiceNo>#{invoice.number}</nsSAFT:InvoiceNo>
            <nsSAFT:SupplierInfo>
              <nsSAFT:SupplierID>#{invoice.supplier_id || ""}</nsSAFT:SupplierID>
              <nsSAFT:Name>#{escape_xml(invoice.supplier_name || "")}</nsSAFT:Name>
              <nsSAFT:BillingAddress>
                <nsSAFT:StreetName>#{escape_xml(invoice.supplier_address || "")}</nsSAFT:StreetName>
                <nsSAFT:City>#{escape_xml(invoice.supplier_city || "")}</nsSAFT:City>
                <nsSAFT:Country>#{invoice.supplier_country || "BG"}</nsSAFT:Country>
              </nsSAFT:BillingAddress>
            </nsSAFT:SupplierInfo>
            <nsSAFT:AccountID>401</nsSAFT:AccountID>
            <nsSAFT:Period>#{invoice.date.month}</nsSAFT:Period>
            <nsSAFT:PeriodYear>#{invoice.date.year}</nsSAFT:PeriodYear>
            <nsSAFT:InvoiceDate>#{format_date(invoice.date)}</nsSAFT:InvoiceDate>
            <nsSAFT:InvoiceType>#{invoice.invoice_type || "01"}</nsSAFT:InvoiceType>
            <nsSAFT:SelfBillingIndicator>N</nsSAFT:SelfBillingIndicator>
            <nsSAFT:SourceID>#{invoice.created_by || "system"}</nsSAFT:SourceID>
            <nsSAFT:GLPostingDate>#{format_date(invoice.posted_at || invoice.date)}</nsSAFT:GLPostingDate>
            <nsSAFT:TransactionID>#{invoice.journal_entry_id || ""}</nsSAFT:TransactionID>
    #{lines_xml}
            <nsSAFT:InvoiceDocumentTotals>
              <nsSAFT:TaxInformationTotals>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>#{invoice.vat_rate || "20"}</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>#{format_decimal(invoice.vat_rate || Decimal.new(20))}</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>#{format_decimal(invoice.subtotal)}</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>#{format_decimal(invoice.vat_amount)}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{invoice.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(invoice.vat_amount)}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformationTotals>
              <nsSAFT:NetTotal>#{format_decimal(invoice.subtotal)}</nsSAFT:NetTotal>
              <nsSAFT:GrossTotal>#{format_decimal(invoice.total)}</nsSAFT:GrossTotal>
            </nsSAFT:InvoiceDocumentTotals>
          </nsSAFT:Invoice>
    """
  end

  defp build_purchase_invoice_line(line, index) do
    """
            <nsSAFT:InvoiceLine>
              <nsSAFT:LineNumber>#{index}</nsSAFT:LineNumber>
              <nsSAFT:AccountID>#{line.account_code || "401"}</nsSAFT:AccountID>
              <nsSAFT:ProductCode>#{line.product_code || ""}</nsSAFT:ProductCode>
              <nsSAFT:ProductDescription>#{escape_xml(line.description || line.product_name || "")}</nsSAFT:ProductDescription>
              <nsSAFT:Quantity>#{format_decimal(line.quantity)}</nsSAFT:Quantity>
              <nsSAFT:InvoiceUOM>#{line.unit || "PCE"}</nsSAFT:InvoiceUOM>
              <nsSAFT:UnitPrice>#{format_decimal(line.unit_price)}</nsSAFT:UnitPrice>
              <nsSAFT:TaxPointDate>#{format_date(line.date || Date.utc_today())}</nsSAFT:TaxPointDate>
              <nsSAFT:Description>#{escape_xml(line.description || "")}</nsSAFT:Description>
              <nsSAFT:InvoiceLineAmount>
                <nsSAFT:Amount>#{format_decimal(line.amount)}</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>#{format_decimal(line.amount)}</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
              </nsSAFT:InvoiceLineAmount>
              <nsSAFT:DebitCreditIndicator>D</nsSAFT:DebitCreditIndicator>
              <nsSAFT:TaxInformation>
                <nsSAFT:TaxType>VAT</nsSAFT:TaxType>
                <nsSAFT:TaxCode>#{line.vat_rate || "20"}</nsSAFT:TaxCode>
                <nsSAFT:TaxPercentage>#{format_decimal(line.vat_rate || Decimal.new(20))}</nsSAFT:TaxPercentage>
                <nsSAFT:TaxBase>#{format_decimal(line.amount)}</nsSAFT:TaxBase>
                <nsSAFT:TaxAmount>
                  <nsSAFT:Amount>#{format_decimal(line.vat_amount || Decimal.new(0))}</nsSAFT:Amount>
                  <nsSAFT:CurrencyCode>#{line.currency || "BGN"}</nsSAFT:CurrencyCode>
                  <nsSAFT:CurrencyAmount>#{format_decimal(line.vat_amount || Decimal.new(0))}</nsSAFT:CurrencyAmount>
                  <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
                </nsSAFT:TaxAmount>
              </nsSAFT:TaxInformation>
            </nsSAFT:InvoiceLine>
    """
  end

  # Payments - Плащания
  defp build_payments(tenant_id, year, month) do
    payments = get_payments(tenant_id, year, month)
    total_amount =
      payments
      |> Enum.reduce(Decimal.new(0), fn p, acc -> Decimal.add(acc, p.amount) end)

    payments_xml =
      if Enum.empty?(payments) do
        build_placeholder_payment(year, month)
      else
        payments
        |> Enum.map(&build_payment/1)
        |> Enum.join("\n")
      end

    """
      <nsSAFT:Payments>
        <nsSAFT:NumberOfEntries>#{length(payments)}</nsSAFT:NumberOfEntries>
        <nsSAFT:TotalDebit>#{format_decimal(total_amount)}</nsSAFT:TotalDebit>
        <nsSAFT:TotalCredit>#{format_decimal(total_amount)}</nsSAFT:TotalCredit>
  #{payments_xml}
      </nsSAFT:Payments>
    """
  end

  defp build_placeholder_payment(year, month) do
    date = Date.new!(year, month, 1)
    """
          <nsSAFT:Payment>
            <nsSAFT:PaymentRefNo>0</nsSAFT:PaymentRefNo>
            <nsSAFT:Period>#{month}</nsSAFT:Period>
            <nsSAFT:PeriodYear>#{year}</nsSAFT:PeriodYear>
            <nsSAFT:TransactionID></nsSAFT:TransactionID>
            <nsSAFT:TransactionDate>#{Date.to_iso8601(date)}</nsSAFT:TransactionDate>
            <nsSAFT:PaymentMethod>03</nsSAFT:PaymentMethod>
            <nsSAFT:Description>Няма плащания за периода</nsSAFT:Description>
            <nsSAFT:SourceID>system</nsSAFT:SourceID>
            <nsSAFT:PaymentLine>
              <nsSAFT:LineNumber>1</nsSAFT:LineNumber>
              <nsSAFT:SourceDocumentID></nsSAFT:SourceDocumentID>
              <nsSAFT:AccountID>503</nsSAFT:AccountID>
              <nsSAFT:CustomerID></nsSAFT:CustomerID>
              <nsSAFT:SupplierID></nsSAFT:SupplierID>
              <nsSAFT:DebitCreditIndicator>D</nsSAFT:DebitCreditIndicator>
              <nsSAFT:PaymentLineAmount>
                <nsSAFT:Amount>0.00</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>BGN</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>0.00</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>1.00</nsSAFT:ExchangeRate>
              </nsSAFT:PaymentLineAmount>
            </nsSAFT:PaymentLine>
          </nsSAFT:Payment>
    """
  end

  defp build_payment(payment) do
    # Determine debit/credit indicator based on payment type
    debit_credit = if payment.customer_id, do: "C", else: "D"

    """
          <nsSAFT:Payment>
            <nsSAFT:PaymentRefNo>#{payment.reference || payment.id}</nsSAFT:PaymentRefNo>
            <nsSAFT:Period>#{payment.date.month}</nsSAFT:Period>
            <nsSAFT:PeriodYear>#{payment.date.year}</nsSAFT:PeriodYear>
            <nsSAFT:TransactionID>#{payment.journal_entry_id || ""}</nsSAFT:TransactionID>
            <nsSAFT:TransactionDate>#{format_date(payment.date)}</nsSAFT:TransactionDate>
            <nsSAFT:PaymentMethod>#{payment.payment_method || "03"}</nsSAFT:PaymentMethod>
            <nsSAFT:Description>#{escape_xml(payment.description || "")}</nsSAFT:Description>
            <nsSAFT:SourceID>#{payment.created_by || "system"}</nsSAFT:SourceID>
            <nsSAFT:PaymentLine>
              <nsSAFT:LineNumber>1</nsSAFT:LineNumber>
              <nsSAFT:SourceDocumentID>#{payment.invoice_id || ""}</nsSAFT:SourceDocumentID>
              <nsSAFT:AccountID>#{payment.account_code || "503"}</nsSAFT:AccountID>
              <nsSAFT:CustomerID>#{payment.customer_id || ""}</nsSAFT:CustomerID>
              <nsSAFT:SupplierID>#{payment.supplier_id || ""}</nsSAFT:SupplierID>
              <nsSAFT:DebitCreditIndicator>#{debit_credit}</nsSAFT:DebitCreditIndicator>
              <nsSAFT:PaymentLineAmount>
                <nsSAFT:Amount>#{format_decimal(payment.amount)}</nsSAFT:Amount>
                <nsSAFT:CurrencyCode>#{payment.currency || "BGN"}</nsSAFT:CurrencyCode>
                <nsSAFT:CurrencyAmount>#{format_decimal(payment.currency_amount || payment.amount)}</nsSAFT:CurrencyAmount>
                <nsSAFT:ExchangeRate>#{format_decimal(payment.exchange_rate || Decimal.new(1))}</nsSAFT:ExchangeRate>
              </nsSAFT:PaymentLineAmount>
            </nsSAFT:PaymentLine>
          </nsSAFT:Payment>
    """
  end

  # MovementOfGoods - Движения на стоки (за OnDemand)
  defp build_movement_of_goods(tenant_id, start_date, end_date) do
    movements = get_stock_movements(tenant_id, start_date, end_date)

    if Enum.empty?(movements) do
      ""
    else
      movements_xml =
        movements
        |> Enum.map(&build_stock_movement/1)
        |> Enum.join("\n")

      """
        <nsSAFT:MovementOfGoods>
          <nsSAFT:NumberOfMovementLines>#{length(movements)}</nsSAFT:NumberOfMovementLines>
          <nsSAFT:TotalQuantityIssued>#{calculate_quantity_issued(movements)}</nsSAFT:TotalQuantityIssued>
          <nsSAFT:TotalQuantityReceived>#{calculate_quantity_received(movements)}</nsSAFT:TotalQuantityReceived>
    #{movements_xml}
        </nsSAFT:MovementOfGoods>
      """
    end
  end

  defp build_stock_movement(movement) do
    movement_type = StockMovementType.from_internal_type(movement.movement_type)

    """
          <nsSAFT:StockMovement>
            <nsSAFT:MovementReference>#{movement.reference || movement.id}</nsSAFT:MovementReference>
            <nsSAFT:MovementDate>#{format_date(movement.date)}</nsSAFT:MovementDate>
            <nsSAFT:MovementType>#{movement_type}</nsSAFT:MovementType>
            <nsSAFT:SourceID>#{movement.created_by || "system"}</nsSAFT:SourceID>
            <nsSAFT:MovementComments>#{escape_xml(movement.description || "")}</nsSAFT:MovementComments>
    #{build_movement_lines(movement.lines || [movement])}
          </nsSAFT:StockMovement>
    """
  end

  defp build_movement_lines(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} -> build_movement_line(line, idx) end)
    |> Enum.join("\n")
  end

  defp build_movement_line(line, index) do
    movement_type = StockMovementType.from_internal_type(line.movement_type || "other")

    """
            <nsSAFT:Line>
              <nsSAFT:LineNumber>#{index}</nsSAFT:LineNumber>
              <nsSAFT:ProductCode>#{line.product_code || ""}</nsSAFT:ProductCode>
              <nsSAFT:ProductDescription>#{escape_xml(line.product_name || "")}</nsSAFT:ProductDescription>
              <nsSAFT:ShipFromWarehouseID>#{line.from_warehouse_id || ""}</nsSAFT:ShipFromWarehouseID>
              <nsSAFT:ShipToWarehouseID>#{line.to_warehouse_id || ""}</nsSAFT:ShipToWarehouseID>
              <nsSAFT:MovementSubType>#{movement_type}</nsSAFT:MovementSubType>
              <nsSAFT:Quantity>#{format_decimal(line.quantity)}</nsSAFT:Quantity>
              <nsSAFT:UnitOfMeasure>#{line.unit || "PCE"}</nsSAFT:UnitOfMeasure>
              <nsSAFT:UnitPrice>#{format_decimal(line.unit_price || Decimal.new(0))}</nsSAFT:UnitPrice>
              <nsSAFT:Description>#{escape_xml(line.description || "")}</nsSAFT:Description>
            </nsSAFT:Line>
    """
  end

  defp calculate_quantity_issued(movements) do
    movements
    |> Enum.filter(fn m -> m.movement_type in ~w(sale transfer production_input scrap) end)
    |> Enum.reduce(Decimal.new(0), fn m, acc -> Decimal.add(acc, m.quantity || Decimal.new(0)) end)
    |> format_decimal()
  end

  defp calculate_quantity_received(movements) do
    movements
    |> Enum.filter(fn m -> m.movement_type in ~w(purchase production_output transfer_in) end)
    |> Enum.reduce(Decimal.new(0), fn m, acc -> Decimal.add(acc, m.quantity || Decimal.new(0)) end)
    |> format_decimal()
  end

  # AssetTransactions - Транзакции с активи (за Annual)
  defp build_asset_transactions(tenant_id, year) do
    transactions = get_asset_transactions(tenant_id, year)

    if Enum.empty?(transactions) do
      ""
    else
      transactions_xml =
        transactions
        |> Enum.map(&build_asset_transaction/1)
        |> Enum.join("\n")

      """
        <nsSAFT:AssetTransactions>
          <nsSAFT:NumberOfAssetTransactions>#{length(transactions)}</nsSAFT:NumberOfAssetTransactions>
    #{transactions_xml}
        </nsSAFT:AssetTransactions>
      """
    end
  end

  defp build_asset_transaction(transaction) do
    transaction_type = AssetMovementType.from_internal_type(transaction.transaction_type)

    """
          <nsSAFT:AssetTransaction>
            <nsSAFT:AssetTransactionID>#{transaction.id}</nsSAFT:AssetTransactionID>
            <nsSAFT:AssetID>#{transaction.asset_code}</nsSAFT:AssetID>
            <nsSAFT:AssetTransactionType>#{transaction_type}</nsSAFT:AssetTransactionType>
            <nsSAFT:Description>#{escape_xml(transaction.description || AssetMovementType.name_bg(transaction_type))}</nsSAFT:Description>
            <nsSAFT:AssetTransactionDate>#{format_date(transaction.transaction_date)}</nsSAFT:AssetTransactionDate>
    #{build_asset_supplier_customer(transaction)}
            <nsSAFT:TransactionID>#{transaction.journal_entry_id || ""}</nsSAFT:TransactionID>
            <nsSAFT:AssetTransactionValuations>
              <nsSAFT:AssetTransactionValuation>
                <nsSAFT:AcquisitionAndProductionCostsOnTransaction>#{format_decimal(transaction.acquisition_cost || Decimal.new(0))}</nsSAFT:AcquisitionAndProductionCostsOnTransaction>
                <nsSAFT:BookValueOnTransaction>#{format_decimal(transaction.book_value || Decimal.new(0))}</nsSAFT:BookValueOnTransaction>
                <nsSAFT:AssetTransactionAmount>#{format_decimal(transaction.amount)}</nsSAFT:AssetTransactionAmount>
              </nsSAFT:AssetTransactionValuation>
            </nsSAFT:AssetTransactionValuations>
          </nsSAFT:AssetTransaction>
    """
  end

  defp build_asset_supplier_customer(transaction) do
    if transaction.supplier_name || transaction.customer_name do
      name = transaction.supplier_name || transaction.customer_name
      id = transaction.supplier_id || transaction.customer_id || ""

      """
            <nsSAFT:AssetSupplierCustomer>
              <nsSAFT:SupplierCustomerName>#{escape_xml(name)}</nsSAFT:SupplierCustomerName>
              <nsSAFT:SupplierCustomerID>#{id}</nsSAFT:SupplierCustomerID>
              <nsSAFT:PostalAddress>
                <nsSAFT:City>#{escape_xml(transaction.city || "")}</nsSAFT:City>
                <nsSAFT:Country>#{transaction.country || "BG"}</nsSAFT:Country>
              </nsSAFT:PostalAddress>
            </nsSAFT:AssetSupplierCustomer>
      """
    else
      ""
    end
  end

  # Database queries

  defp get_sales_invoices(tenant_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    try do
      from(i in CyberCore.Sales.Invoice,
        where:
          i.tenant_id == ^tenant_id and
            i.date >= ^start_date and
            i.date <= ^end_date,
        preload: [:lines, :customer],
        order_by: [asc: i.date, asc: i.number]
      )
      |> Repo.all()
      |> Enum.map(&normalize_sales_invoice/1)
    rescue
      _ -> []
    end
  end

  defp normalize_sales_invoice(invoice) do
    %{
      id: invoice.id,
      number: invoice.number,
      date: invoice.date,
      customer_id: invoice.customer_id,
      customer_name: invoice.customer && invoice.customer.name,
      customer_address: invoice.customer && invoice.customer.address,
      customer_city: invoice.customer && invoice.customer.city,
      customer_postal_code: invoice.customer && invoice.customer.postal_code,
      customer_country: (invoice.customer && invoice.customer.country) || "BG",
      invoice_type: invoice.type || "01",
      created_by: invoice.created_by,
      posted_at: invoice.posted_at,
      journal_entry_id: invoice.journal_entry_id,
      subtotal: invoice.subtotal || Decimal.new(0),
      vat_amount: invoice.vat_amount || Decimal.new(0),
      vat_rate: invoice.vat_rate,
      total: invoice.total || Decimal.new(0),
      currency: invoice.currency || "BGN",
      lines: normalize_invoice_lines(invoice.lines || [])
    }
  end

  defp normalize_invoice_lines(lines) do
    Enum.map(lines, fn line ->
      %{
        product_code: line.product_code || (line.product && line.product.code),
        product_name: line.product_name || (line.product && line.product.name),
        description: line.description,
        quantity: line.quantity || Decimal.new(1),
        unit: line.unit || "PCE",
        unit_price: line.unit_price || Decimal.new(0),
        amount: line.amount || line.total || Decimal.new(0),
        vat_rate: line.vat_rate,
        vat_amount: line.vat_amount || Decimal.new(0),
        account_code: line.account_code,
        currency: line.currency || "BGN",
        date: line.date
      }
    end)
  end

  defp get_purchase_invoices(tenant_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    try do
      from(i in CyberCore.Purchase.SupplierInvoice,
        where:
          i.tenant_id == ^tenant_id and
            i.date >= ^start_date and
            i.date <= ^end_date,
        preload: [:lines, :supplier],
        order_by: [asc: i.date, asc: i.number]
      )
      |> Repo.all()
      |> Enum.map(&normalize_purchase_invoice/1)
    rescue
      _ -> []
    end
  end

  defp normalize_purchase_invoice(invoice) do
    %{
      id: invoice.id,
      number: invoice.number,
      date: invoice.date,
      supplier_id: invoice.supplier_id,
      supplier_name: invoice.supplier && invoice.supplier.name,
      supplier_address: invoice.supplier && invoice.supplier.address,
      supplier_city: invoice.supplier && invoice.supplier.city,
      supplier_country: (invoice.supplier && invoice.supplier.country) || "BG",
      invoice_type: invoice.type || "01",
      created_by: invoice.created_by,
      posted_at: invoice.posted_at,
      journal_entry_id: invoice.journal_entry_id,
      subtotal: invoice.subtotal || Decimal.new(0),
      vat_amount: invoice.vat_amount || Decimal.new(0),
      vat_rate: invoice.vat_rate,
      total: invoice.total || Decimal.new(0),
      currency: invoice.currency || "BGN",
      lines: normalize_invoice_lines(invoice.lines || [])
    }
  end

  defp get_payments(_tenant_id, _year, _month) do
    # TODO: Имплементирай когато Payment модулът е готов
    # За момента връщаме празен списък
    []
  end

  defp get_stock_movements(tenant_id, start_date, end_date) do
    try do
      from(m in CyberCore.Inventory.StockMovement,
        where:
          m.tenant_id == ^tenant_id and
            m.date >= ^start_date and
            m.date <= ^end_date,
        preload: [:product, :from_warehouse, :to_warehouse],
        order_by: [asc: m.date, asc: m.id]
      )
      |> Repo.all()
      |> Enum.map(&normalize_stock_movement/1)
    rescue
      _ -> []
    end
  end

  defp normalize_stock_movement(movement) do
    %{
      id: movement.id,
      reference: movement.reference,
      date: movement.date,
      movement_type: movement.movement_type,
      product_code: movement.product && movement.product.code,
      product_name: movement.product && movement.product.name,
      from_warehouse_id: movement.from_warehouse && movement.from_warehouse.code,
      to_warehouse_id: movement.to_warehouse && movement.to_warehouse.code,
      quantity: movement.quantity,
      unit: movement.unit || (movement.product && movement.product.unit) || "PCE",
      unit_price: movement.unit_price,
      description: movement.description,
      created_by: movement.created_by
    }
  end

  defp get_asset_transactions(tenant_id, year) do
    start_date = Date.new!(year, 1, 1)
    end_date = Date.new!(year, 12, 31)

    try do
      from(t in CyberCore.Accounting.AssetTransaction,
        join: a in CyberCore.Accounting.Asset,
        on: t.asset_id == a.id,
        where:
          a.tenant_id == ^tenant_id and
            t.transaction_date >= ^start_date and
            t.transaction_date <= ^end_date,
        preload: [asset: [:supplier]],
        order_by: [asc: t.transaction_date, asc: t.id]
      )
      |> Repo.all()
      |> Enum.map(&normalize_asset_transaction/1)
    rescue
      _ -> []
    end
  end

  defp normalize_asset_transaction(transaction) do
    %{
      id: transaction.id,
      asset_code: transaction.asset && transaction.asset.code,
      transaction_type: transaction.transaction_type,
      transaction_date: transaction.transaction_date,
      description: transaction.description,
      amount: transaction.amount || Decimal.new(0),
      acquisition_cost: transaction.asset && transaction.asset.acquisition_cost,
      book_value: transaction.book_value,
      journal_entry_id: transaction.journal_entry_id,
      supplier_name: transaction.asset && transaction.asset.supplier && transaction.asset.supplier.name,
      supplier_id: transaction.asset && transaction.asset.supplier_id,
      customer_name: nil,
      customer_id: nil,
      city: transaction.asset && transaction.asset.supplier && transaction.asset.supplier.city,
      country: (transaction.asset && transaction.asset.supplier && transaction.asset.supplier.country) || "BG"
    }
  end

  defp calculate_invoice_totals(invoices) do
    invoices
    |> Enum.reduce({Decimal.new(0), Decimal.new(0)}, fn invoice, {debit, credit} ->
      total = invoice.total || Decimal.new(0)
      {Decimal.add(debit, total), Decimal.add(credit, total)}
    end)
  end

  # Helper functions

  defp format_date(nil), do: Date.utc_today() |> Date.to_iso8601()
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt) |> Date.to_iso8601()
  defp format_date(date), do: to_string(date)

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
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
