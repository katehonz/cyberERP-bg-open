defmodule CyberCore.Accounting.NapExport do
  @moduledoc """
  Генериране на файлове за НАП според ППДС 2025.

  Форматът е текстови файлове с фиксирана дължина на полетата:
  - Кодировка: windows-1251 (cp-1251)
  - Без разделители между полетата
  - Празните полета се попълват с интервали
  - Числата са подравнени вдясно без водещи нули
  - Текстът е подравнен вляво
  - Дати във формат dd/mm/yyyy
  - Край на ред: CRLF (\r\n)

  Генерира три файла:
  - DEKLAR.TXT - Декларация (обобщение)
  - POKUPKI.TXT - Дневник покупки
  - PRODAGBI.TXT - Дневник продажби
  """

  alias CyberCore.Accounting.{Vat, VatReturn, VatSalesRegister, VatPurchaseRegister}
  alias CyberCore.Settings
  alias CyberCore.Repo

  import Ecto.Query

  @doc """
  Генерира всички три NAP файла за даден период.
  Връща tuple с пътищата до файловете или грешка.
  """
  def generate_nap_files(tenant_id, year, month, output_dir \\ "/tmp") do
    with {:ok, vat_return} <- Vat.get_or_create_vat_return(tenant_id, year, month),
         {:ok, deklar_path} <- generate_deklar(vat_return, output_dir),
         {:ok, pokupki_path} <- generate_pokupki(tenant_id, year, month, output_dir),
         {:ok, prodagbi_path} <- generate_prodagbi(tenant_id, year, month, output_dir) do
      {:ok,
       %{
         deklar: deklar_path,
         pokupki: pokupki_path,
         prodagbi: prodagbi_path
       }}
    end
  end

  @doc """
  Генерира DEKLAR.TXT файл.
  """
  def generate_deklar(%VatReturn{tenant_id: tenant_id} = vat_return, output_dir) do
    # Формат на DEKLAR.TXT според ППДС 2025
    # Съдържа обобщена информация за периода

    # Get document counts from registers
    sales_count =
      count_sales_documents(tenant_id, vat_return.period_year, vat_return.period_month)

    purchases_count =
      count_purchase_documents(tenant_id, vat_return.period_year, vat_return.period_month)

    filename = Path.join(output_dir, "DEKLAR.TXT")

    content =
      format_deklar_line(vat_return, sales_count, purchases_count)
      |> encode_windows1251()

    case File.write(filename, content) do
      :ok -> {:ok, filename}
      error -> error
    end
  end

  defp count_sales_documents(tenant_id, year, month) do
    Repo.aggregate(
      from(s in VatSalesRegister,
        where:
          s.tenant_id == ^tenant_id and
            s.period_year == ^year and
            s.period_month == ^month and
            s.document_type not in ["11", "12", "13", "04"]
      ),
      :count
    )
  end

  defp count_purchase_documents(tenant_id, year, month) do
    Repo.aggregate(
      from(p in VatPurchaseRegister,
        where:
          p.tenant_id == ^tenant_id and
            p.period_year == ^year and
            p.period_month == ^month and
            p.document_type not in ["11", "12", "13", "94", "05"]
      ),
      :count
    )
  end

  @doc """
  Генерира POKUPKI.TXT файл.
  """
  def generate_pokupki(tenant_id, year, month, output_dir) do
    filename = Path.join(output_dir, "POKUPKI.TXT")

    purchases = fetch_purchase_register(tenant_id, year, month)

    content =
      purchases
      |> Enum.with_index(1)
      |> Enum.map(fn {purchase, index} ->
        format_pokupki_line(purchase, index)
      end)
      |> Enum.join("\r\n")
      |> encode_windows1251()

    case File.write(filename, content) do
      :ok -> {:ok, filename}
      error -> error
    end
  end

  @doc """
  Генерира PRODAGBI.TXT файл.
  """
  def generate_prodagbi(tenant_id, year, month, output_dir) do
    filename = Path.join(output_dir, "PRODAGBI.TXT")

    sales = fetch_sales_register(tenant_id, year, month)

    content =
      sales
      |> Enum.with_index(1)
      |> Enum.map(fn {sale, index} ->
        format_prodagbi_line(sale, index)
      end)
      |> Enum.join("\r\n")
      |> encode_windows1251()

    case File.write(filename, content) do
      :ok -> {:ok, filename}
      error -> error
    end
  end

  # ===== Private Helper Functions =====

  defp fetch_sales_register(tenant_id, year, month) do
    Repo.all(
      from s in VatSalesRegister,
        where:
          s.tenant_id == ^tenant_id and
            s.period_year == ^year and
            s.period_month == ^month,
        order_by: [asc: s.document_date, asc: s.document_number]
    )
  end

  defp fetch_purchase_register(tenant_id, year, month) do
    Repo.all(
      from p in VatPurchaseRegister,
        where:
          p.tenant_id == ^tenant_id and
            p.period_year == ^year and
            p.period_month == ^month,
        order_by: [asc: p.document_date, asc: p.document_number]
    )
  end

  # Format DEKLAR.TXT line according to PPDDS specification
  defp format_deklar_line(
         %VatReturn{tenant_id: tenant_id} = vat_return,
         sales_count,
         purchases_count
       ) do
    period = format_period(vat_return.period_year, vat_return.period_month)
    {:ok, settings} = Settings.get_or_create_company_settings(tenant_id)
    vat_number = settings.vat_number
    company_name = settings.company_name

    # Aggregate sales by column code for detailed breakdown
    sales_by_column =
      aggregate_sales_by_column(tenant_id, vat_return.period_year, vat_return.period_month)

    # Aggregate purchases by credit type
    purchases_by_credit =
      aggregate_purchases_by_credit(tenant_id, vat_return.period_year, vat_return.period_month)

    # Calculate coefficient (коефициент) - simplified to 1.00 for now
    coefficient = "1.00"

    # Calculate total tax credit: full + (partial * coefficient) + annual_adjustment
    total_tax_credit =
      Decimal.add(
        vat_return.total_deductible_vat || Decimal.new(0),
        # annual adjustment
        Decimal.new(0)
      )

    # Calculate VAT to pay or refund
    vat_difference =
      Decimal.sub(
        vat_return.total_sales_vat || Decimal.new(0),
        total_tax_credit
      )

    vat_to_pay =
      if Decimal.compare(vat_difference, Decimal.new(0)) == :gt do
        vat_difference
      else
        Decimal.new(0)
      end

    vat_to_refund =
      if Decimal.compare(vat_difference, Decimal.new(0)) == :lt do
        Decimal.abs(vat_difference)
      else
        Decimal.new(0)
      end

    [
      # 00-01: VAT number (15 chars)
      pad_right(vat_number, 15),
      # 00-02: Company name (50 chars)
      pad_right(String.slice(company_name, 0, 50), 50),
      # 00-03: Period YYYYMM (6 chars)
      pad_right(period, 6),
      # 00-04: Person submitting (50 chars) - using company name for now
      pad_right(String.slice(company_name, 0, 50), 50),
      # 00-05: Sales document count (15 chars, right-aligned)
      pad_left(Integer.to_string(sales_count), 15),
      # 00-06: Purchase document count (15 chars, right-aligned)
      pad_left(Integer.to_string(purchases_count), 15),
      # SALES SECTION
      # *01-01: Total taxable base (15 chars)
      pad_left(format_decimal(vat_return.total_sales_taxable), 15),
      # *01-20: Total VAT (15 chars)
      pad_left(format_decimal(vat_return.total_sales_vat), 15),
      # *01-11: Taxable base 20% (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про11_base", Decimal.new(0))), 15),
      # *01-21: VAT 20% (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про11_vat", Decimal.new(0))), 15),
      # *01-12: ICA taxable base (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про12_base", Decimal.new(0))), 15),
      # *01-22: ICA VAT (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про12_vat", Decimal.new(0))), 15),
      # *01-23: VAT for personal use (15 chars)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # *01-13: Taxable base 9% (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про17_base", Decimal.new(0))), 15),
      # *01-24: VAT 9% (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про17_vat", Decimal.new(0))), 15),
      # *01-14: Taxable base 0% chapter 3 (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про19_base", Decimal.new(0))), 15),
      # *01-15: Taxable base 0% IC supplies (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про20_base", Decimal.new(0))), 15),
      # *01-16: Taxable base 0% Art.140/146/173 (15 chars)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # *01-17: Taxable base services Art.21 (15 chars)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # *01-18: Taxable base Art.69 (15 chars)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # *01-19: Exempt deliveries (15 chars)
      pad_left(format_decimal(Map.get(sales_by_column, "про23_base", Decimal.new(0))), 15),
      # PURCHASES SECTION
      # *01-30: Taxable base without credit (15 chars)
      pad_left(format_decimal(Map.get(purchases_by_credit, "none_base", Decimal.new(0))), 15),
      # *01-31: Taxable base with full credit (15 chars)
      pad_left(format_decimal(Map.get(purchases_by_credit, "full_base", Decimal.new(0))), 15),
      # *01-41: VAT with full credit (15 chars)
      pad_left(format_decimal(Map.get(purchases_by_credit, "full_vat", Decimal.new(0))), 15),
      # *01-32: Taxable base with partial credit (15 chars)
      pad_left(format_decimal(Map.get(purchases_by_credit, "partial_base", Decimal.new(0))), 15),
      # *01-42: VAT with partial credit (15 chars)
      pad_left(format_decimal(Map.get(purchases_by_credit, "partial_vat", Decimal.new(0))), 15),
      # *01-43: Annual adjustment (15 chars)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # RESULT SECTION
      # 01-33: Coefficient (4 chars)
      pad_right(coefficient, 4),
      # 01-40: Total tax credit (15 chars)
      pad_left(format_decimal(total_tax_credit), 15),
      # 01-50: VAT to pay (15 chars)
      pad_left(format_decimal(vat_to_pay), 15),
      # 01-60: VAT to refund (15 chars)
      pad_left(format_decimal(vat_to_refund), 15)
    ]
    |> Enum.join()
  end

  # Aggregate sales register data by column code
  defp aggregate_sales_by_column(tenant_id, year, month) do
    sales =
      Repo.all(
        from s in VatSalesRegister,
          where:
            s.tenant_id == ^tenant_id and
              s.period_year == ^year and
              s.period_month == ^month and
              s.document_type not in ["11", "12", "13", "04"],
          select: {s.column_code, s.taxable_base, s.vat_amount}
      )

    Enum.reduce(sales, %{}, fn {column_code, base, vat}, acc ->
      base_key = "#{column_code}_base"
      vat_key = "#{column_code}_vat"

      acc
      |> Map.update(base_key, base || Decimal.new(0), &Decimal.add(&1, base || Decimal.new(0)))
      |> Map.update(vat_key, vat || Decimal.new(0), &Decimal.add(&1, vat || Decimal.new(0)))
    end)
  end

  # Aggregate purchase register data by credit type
  defp aggregate_purchases_by_credit(tenant_id, year, month) do
    purchases =
      Repo.all(
        from p in VatPurchaseRegister,
          where:
            p.tenant_id == ^tenant_id and
              p.period_year == ^year and
              p.period_month == ^month and
              p.document_type not in ["11", "12", "13", "94", "05"],
          select: {p.deductible_credit_type, p.taxable_base, p.deductible_vat_amount}
      )

    Enum.reduce(purchases, %{}, fn {credit_type, base, vat}, acc ->
      base_key = "#{credit_type}_base"
      vat_key = "#{credit_type}_vat"

      acc
      |> Map.update(base_key, base || Decimal.new(0), &Decimal.add(&1, base || Decimal.new(0)))
      |> Map.update(vat_key, vat || Decimal.new(0), &Decimal.add(&1, vat || Decimal.new(0)))
    end)
  end

  # Format POKUPKI.TXT line according to PPDDS specification
  defp format_pokupki_line(%VatPurchaseRegister{tenant_id: tenant_id} = purchase, record_number) do
    company_vat = Settings.get_vat_number(tenant_id)
    period = format_period(purchase.period_year, purchase.period_month)

    # Format according to fixed-width specification from PPDDS_2025_.html
    # Complete structure with all fields
    [
      # 03-02: Company VAT number (15 chars, left-aligned)
      pad_right(company_vat, 15),
      # 03-01: Period YYYYMM (6 chars, left-aligned)
      pad_right(period, 6),
      # 03-03: Branch/unit (4 chars, right-aligned)
      pad_left("", 4),
      # 03-04: Record number (15 chars, right-aligned)
      pad_left(Integer.to_string(record_number), 15),
      # 03-05: Document type (2 chars, left-aligned)
      pad_right(purchase.document_type || "01", 2),
      # Spacing after document type (14 chars)
      pad_right("", 14),
      # 03-06: Document number (20 chars, left-aligned)
      pad_right(String.slice(purchase.document_number || "", 0, 20), 20),
      # 03-07: Document date dd/mm/yyyy (10 chars)
      format_date(purchase.document_date),
      # 03-08: Supplier VAT/ID number (15 chars, left-aligned)
      pad_right(purchase.supplier_vat_number || purchase.supplier_eik || "", 15),
      # 03-09: Supplier name (50 chars, left-aligned)
      pad_right(String.slice(purchase.supplier_name || "", 0, 50), 50),
      # 03-10: Supplier city (30 chars, left-aligned)
      pad_right(String.slice(purchase.supplier_city || "", 0, 30), 30),
      # 03-30: Taxable base without VAT credit (15 chars, right-aligned)
      pad_left(format_decimal(get_purchase_amount_by_credit(purchase, :none)), 15),
      # 03-31: Taxable base with full VAT credit (15 chars, right-aligned)
      pad_left(format_decimal(get_purchase_amount_by_credit(purchase, :full)), 15),
      # 03-41: VAT with full credit (15 chars, right-aligned)
      pad_left(format_decimal(get_purchase_vat_by_credit(purchase, :full)), 15),
      # 03-32: Taxable base with partial VAT credit (15 chars, right-aligned)
      pad_left(format_decimal(get_purchase_amount_by_credit(purchase, :partial)), 15),
      # 03-42: VAT with partial credit (15 chars, right-aligned)
      pad_left(format_decimal(get_purchase_vat_by_credit(purchase, :partial)), 15),
      # 03-43: Annual adjustment per Art. 73, para. 8 (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 03-44: Taxable base for triangular transaction (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 03-45: Delivery per Art. 163a or import per Art. 167a (2 chars)
      pad_right(purchase.reverse_charge_subcode || "", 2)
    ]
    |> Enum.join()
  end

  # Format PRODAGBI.TXT line according to PPDDS specification
  defp format_prodagbi_line(%VatSalesRegister{tenant_id: tenant_id} = sale, record_number) do
    company_vat = Settings.get_vat_number(tenant_id)
    period = format_period(sale.period_year, sale.period_month)

    # Calculate total taxable base and total VAT for all rates
    taxable_base_total = sale.taxable_base || Decimal.new(0)
    vat_total = sale.vat_amount || Decimal.new(0)

    [
      # 02-00: Company VAT number (15 chars, left-aligned)
      pad_right(company_vat, 15),
      # 02-01: Period YYYYMM (6 chars, left-aligned)
      pad_right(period, 6),
      # 02-02: Branch/unit (4 chars, right-aligned)
      pad_left("", 4),
      # 02-03: Record number (15 chars, right-aligned)
      pad_left(Integer.to_string(record_number), 15),
      # 02-04: Document type (2 chars, left-aligned)
      pad_right(sale.document_type || "01", 2),
      # 02-05: Document number (20 chars, left-aligned)
      pad_right(String.slice(sale.document_number || "", 0, 20), 20),
      # 02-06: Document date dd/mm/yyyy (10 chars)
      format_date(sale.document_date),
      # 02-07: Recipient VAT/ID number (15 chars, left-aligned)
      pad_right(sale.recipient_vat_number || sale.recipient_eik || "", 15),
      # 02-08: Recipient name (50 chars, left-aligned)
      pad_right(String.slice(sale.recipient_name || "", 0, 50), 50),
      # 02-09: Recipient city (30 chars, left-aligned)
      pad_right(String.slice(sale.recipient_city || "", 0, 30), 30),
      # 02-10: Total taxable base (15 chars, right-aligned)
      pad_left(format_decimal(taxable_base_total), 15),
      # 02-20: Total VAT (15 chars, right-aligned)
      pad_left(format_decimal(vat_total), 15),
      # 02-11: Taxable base 20% (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про11")), 15),
      # 02-21: VAT 20% (15 chars, right-aligned)
      pad_left(format_decimal(get_column_vat(sale, "про11")), 15),
      # 02-12: Taxable base ICA (ВОП) (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про12")), 15),
      # 02-26: Taxable base Art. 82 (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-22: VAT for ICA and Art. 82 (15 chars, right-aligned)
      pad_left(format_decimal(get_column_vat(sale, "про12")), 15),
      # 02-23: VAT for personal use (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-13: Taxable base 9% (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про17")), 15),
      # 02-24: VAT 9% (15 chars, right-aligned)
      pad_left(format_decimal(get_column_vat(sale, "про17")), 15),
      # 02-14: Taxable base 0% chapter 3 (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про19")), 15),
      # 02-15: Taxable base 0% IC supplies (ВОД) (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про20")), 15),
      # 02-16: Taxable base 0% Art. 140/146/173 (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-17: Taxable base services Art. 21, para. 2 (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-18: Taxable base Art. 69, para. 2 (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-19: Taxable base exempt deliveries (15 chars, right-aligned)
      pad_left(format_decimal(get_column_amount(sale, "про23")), 15),
      # 02-25: Taxable base triangular transactions (15 chars, right-aligned)
      pad_left(format_decimal(Decimal.new(0)), 15),
      # 02-27: Delivery per Art. 163a or import per Art. 167a (2 chars)
      pad_right(sale.reverse_charge_subcode || "", 2)
    ]
    |> Enum.join()
  end

  # Helper functions for purchase register amounts by deductible credit type
  defp get_purchase_amount_by_credit(
         %VatPurchaseRegister{deductible_credit_type: credit_type, taxable_base: amount},
         target_credit_type
       )
       when credit_type == target_credit_type,
       do: amount || Decimal.new(0)

  defp get_purchase_amount_by_credit(_, _), do: Decimal.new(0)

  defp get_purchase_vat_by_credit(
         %VatPurchaseRegister{deductible_credit_type: credit_type, deductible_vat_amount: amount},
         target_credit_type
       )
       when credit_type == target_credit_type,
       do: amount || Decimal.new(0)

  defp get_purchase_vat_by_credit(_, _), do: Decimal.new(0)

  # Helper functions for sales register amounts by column code
  defp get_column_amount(
         %VatSalesRegister{column_code: column_code, taxable_base: amount},
         target_column
       )
       when column_code == target_column,
       do: amount || Decimal.new(0)

  defp get_column_amount(_, _), do: Decimal.new(0)

  defp get_column_vat(
         %VatSalesRegister{column_code: column_code, vat_amount: amount},
         target_column
       )
       when column_code == target_column,
       do: amount || Decimal.new(0)

  defp get_column_vat(_, _), do: Decimal.new(0)

  # ===== Formatting Helpers =====

  # Pad string to the right with spaces
  defp pad_right(str, width) when is_binary(str) do
    String.pad_trailing(str, width)
  end

  # Pad string to the left with spaces
  defp pad_left(str, width) when is_binary(str) do
    String.pad_leading(str, width)
  end

  # Format decimal number for NAP (no leading zeros, 2 decimal places)
  defp format_decimal(nil), do: "0.00"

  defp format_decimal(%Decimal{} = dec) do
    Decimal.to_string(dec, :normal)
  end

  # Format date as dd/mm/yyyy
  defp format_date(nil), do: pad_right("", 10)

  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%d/%m/%Y")
  end

  # Format period as YYYYMM
  defp format_period(year, month) do
    year_str = Integer.to_string(year)
    month_str = String.pad_leading(Integer.to_string(month), 2, "0")
    year_str <> month_str
  end

  # Encode to windows-1251 (cp-1251)
  defp encode_windows1251(text) do
    # Elixir uses UTF-8 internally, we need to convert to windows-1251
    case Codepagex.from_string(text, "WINDOWS-1251") do
      {:ok, encoded_text} -> encoded_text
      {:error, reason} -> raise "Failed to encode to WINDOWS-1251: #{inspect(reason)}"
    end
  end
end
