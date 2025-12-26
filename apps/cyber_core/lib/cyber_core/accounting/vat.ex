defmodule CyberCore.Accounting.Vat do
  @moduledoc """
  Контекст за ДДС отчетност (VAT Reporting).

  Управлява дневниците на продажби и покупки, както и ДДС декларации.
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Accounting.{VatSalesRegister, VatPurchaseRegister, VatReturn}
  alias CyberCore.Sales.Invoice
  alias Decimal, as: D

  # ============================================================================
  # Sales Register (Дневник продажби)
  # ============================================================================

  @doc """
  Връща записи от дневника продажби за даден период.
  """
  def list_sales_register(tenant_id, year, month) do
    VatSalesRegister
    |> where([r], r.tenant_id == ^tenant_id)
    |> where([r], r.period_year == ^year and r.period_month == ^month)
    |> order_by([r], asc: r.document_date, asc: r.document_number)
    |> preload(:invoice)
    |> Repo.all()
  end

  @doc """
  Създава запис в дневника продажби.
  """
  def create_sales_register_entry(attrs) do
    %VatSalesRegister{}
    |> VatSalesRegister.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Автоматично регистрира фактура в дневника продажби.
  """
  def register_invoice_sale(%Invoice{status: status} = invoice)
      when status in ["issued", "paid"] do
    # Проверка дали вече е регистрирана
    existing =
      VatSalesRegister
      |> where([r], r.invoice_id == ^invoice.id)
      |> Repo.one()

    if existing do
      {:ok, existing}
    else
      attrs = VatSalesRegister.from_invoice(invoice)
      create_sales_register_entry(attrs)
    end
  end

  def register_invoice_sale(_invoice), do: {:error, :invalid_invoice_status}

  @doc """
  Връща запис от дневника продажби по ID на фактура.
  """
  def get_sales_register_by_invoice(invoice_id) do
    VatSalesRegister
    |> where([r], r.invoice_id == ^invoice_id)
    |> Repo.one()
  end

  @doc """
  Изтрива запис от дневника продажби.
  """
  def delete_sales_register_entry(%VatSalesRegister{} = entry) do
    Repo.delete(entry)
  end

  # ============================================================================
  # Purchase Register (Дневник покупки)
  # ============================================================================

  @doc """
  Връща записи от дневника покупки за даден период.
  """
  def list_purchase_register(tenant_id, year, month) do
    VatPurchaseRegister
    |> where([r], r.tenant_id == ^tenant_id)
    |> where([r], r.period_year == ^year and r.period_month == ^month)
    |> order_by([r], asc: r.document_date, asc: r.document_number)
    |> Repo.all()
  end

  @doc """
  Създава запис в дневника покупки.
  """
  def create_purchase_register_entry(attrs) do
    %VatPurchaseRegister{}
    |> VatPurchaseRegister.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира запис в дневника покупки.
  """
  def update_purchase_register_entry(%VatPurchaseRegister{} = entry, attrs) do
    entry
    |> VatPurchaseRegister.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изтрива запис от дневника покупки.
  """
  def delete_purchase_register_entry(%VatPurchaseRegister{} = entry) do
    Repo.delete(entry)
  end

  # ============================================================================
  # VAT Return (ДДС декларация)
  # ============================================================================

  @doc """
  Връща ДДС декларация за даден период или създава нова чернова.
  """
  def get_or_create_vat_return(tenant_id, year, month) do
    case Repo.get_by(VatReturn, tenant_id: tenant_id, period_year: year, period_month: month) do
      nil ->
        create_vat_return(%{
          tenant_id: tenant_id,
          period_year: year,
          period_month: month,
          status: "draft"
        })

      vat_return ->
        {:ok, vat_return}
    end
  end

  @doc """
  Създава нова ДДС декларация.
  """
  def create_vat_return(attrs) do
    %VatReturn{}
    |> VatReturn.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Актуализира ДДС декларация.
  """
  def update_vat_return(%VatReturn{} = vat_return, attrs) do
    vat_return
    |> VatReturn.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изчислява ДДС декларация от дневниците.
  """
  def calculate_vat_return(tenant_id, year, month) do
    # Сума продажби
    sales_totals = calculate_sales_totals(tenant_id, year, month)

    # Сума покупки
    purchase_totals = calculate_purchase_totals(tenant_id, year, month)

    # Изчисли резултат
    diff = D.sub(sales_totals.vat, purchase_totals.deductible_vat)

    {vat_payable, vat_refundable} =
      if D.gt?(diff, 0) do
        {diff, D.new(0)}
      else
        {D.new(0), D.abs(diff)}
      end

    %{
      total_sales_taxable: sales_totals.taxable,
      total_sales_vat: sales_totals.vat,
      total_purchases_taxable: purchase_totals.taxable,
      total_purchases_vat: purchase_totals.vat,
      total_deductible_vat: purchase_totals.deductible_vat,
      vat_payable: vat_payable,
      vat_refundable: vat_refundable
    }
  end

  defp calculate_sales_totals(tenant_id, year, month) do
    result =
      VatSalesRegister
      |> where([r], r.tenant_id == ^tenant_id)
      |> where([r], r.period_year == ^year and r.period_month == ^month)
      |> select([r], %{
        taxable: sum(r.taxable_base),
        vat: sum(r.vat_amount)
      })
      |> Repo.one()

    %{
      taxable: result.taxable || D.new(0),
      vat: result.vat || D.new(0)
    }
  end

  defp calculate_purchase_totals(tenant_id, year, month) do
    result =
      VatPurchaseRegister
      |> where([r], r.tenant_id == ^tenant_id)
      |> where([r], r.period_year == ^year and r.period_month == ^month)
      |> select([r], %{
        taxable: sum(r.taxable_base),
        vat: sum(r.vat_amount),
        deductible_vat: sum(r.deductible_vat_amount)
      })
      |> Repo.one()

    %{
      taxable: result.taxable || D.new(0),
      vat: result.vat || D.new(0),
      deductible_vat: result.deductible_vat || D.new(0)
    }
  end

  @doc """
  Рекалкулира и актуализира ДДС декларация.
  """
  def recalculate_vat_return(tenant_id, year, month) do
    {:ok, vat_return} = get_or_create_vat_return(tenant_id, year, month)

    if vat_return.status == "draft" do
      calculated = calculate_vat_return(tenant_id, year, month)
      update_vat_return(vat_return, calculated)
    else
      {:error, :already_submitted}
    end
  end

  @doc """
  Подава ДДС декларация.
  """
  def submit_vat_return(%VatReturn{status: "draft"} = vat_return) do
    vat_return
    |> VatReturn.changeset(%{
      status: "submitted",
      submission_date: Date.utc_today()
    })
    |> Repo.update()
  end

  def submit_vat_return(_), do: {:error, :invalid_status}

  @doc """
  Връща списък с ДДС декларации за дадена година.
  """
  def list_vat_returns(tenant_id, year) do
    VatReturn
    |> where([r], r.tenant_id == ^tenant_id and r.period_year == ^year)
    |> order_by([r], asc: r.period_month)
    |> Repo.all()
  end
end
