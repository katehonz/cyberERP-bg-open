defmodule CyberCore.Sales do
  @moduledoc """
  Продажби, фактури и клиенти.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo
  alias CyberCore.Sales.{Sale, SaleItem, Invoice, InvoiceLine, Quotation, QuotationLine}
  alias CyberCore.Inventory
  alias CyberCore.Settings.DocumentNumbering
  alias Decimal
  alias CyberCore.Accounting.Vat
  alias CyberCore.Accounting.OssVatRate

  def list_sales(tenant_id, opts \\ []) do
    base_query =
      from s in Sale,
        where: s.tenant_id == ^tenant_id,
        order_by: [desc: s.date],
        preload: [:customer, :sale_items]

    Repo.all(apply_filters(base_query, opts))
  end

  def get_sale!(tenant_id, id, preloads \\ [:customer, :sale_items]) do
    Sale
    |> where([s], s.tenant_id == ^tenant_id and s.id == ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  def get_sale_by_invoice!(tenant_id, invoice) do
    Repo.get_by!(Sale, tenant_id: tenant_id, invoice_number: invoice)
  end

  def create_sale(attrs) do
    %Sale{}
    |> Sale.changeset(attrs)
    |> Repo.insert()
  end

  def create_sale_with_items(sale_attrs, items_attrs, opts \\ []) when is_list(items_attrs) do
    opts = Keyword.merge([create_stock_movements: true], opts)

    Repo.transaction(fn ->
      with {:ok, sale} <- create_sale(sale_attrs),
           {:ok, items} <- insert_sale_items(sale, items_attrs),
           {:ok, updated_sale} <- update_sale_totals(sale, items),
           {:ok, _movements} <- maybe_create_stock_movements(updated_sale, items, opts) do
        Repo.preload(updated_sale, [:customer, :sale_items])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def list_sale_items(sale_id) do
    Repo.all(
      from si in SaleItem,
        where: si.sale_id == ^sale_id,
        order_by: [asc: si.line_no],
        preload: [:product]
    )
  end

  def update_sale(%Sale{} = sale, attrs) do
    sale
    |> Sale.changeset(attrs)
    |> Repo.update()
  end

  def delete_sale(%Sale{} = sale), do: Repo.delete(sale)

  def change_sale(%Sale{} = sale, attrs \\ %{}) do
    Sale.changeset(sale, attrs)
  end

  defp insert_sale_items(%Sale{} = sale, items_attrs) do
    items_attrs
    |> Enum.with_index(1)
    |> Enum.map(fn {attrs, index} ->
      attrs =
        attrs
        |> Map.put_new(:tenant_id, sale.tenant_id)
        |> Map.put(:sale_id, sale.id)
        |> Map.put_new(:line_no, index)

      %SaleItem{}
      |> SaleItem.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp update_sale_totals(%Sale{} = sale, items) do
    total_amount =
      Enum.reduce(items, Decimal.new(0), fn item, acc -> Decimal.add(acc, item.total_amount) end)

    update_sale(sale, %{amount: total_amount})
  end

  defp maybe_create_stock_movements(%Sale{} = sale, items, opts) do
    if Keyword.get(opts, :create_stock_movements, true) != false and sale.warehouse_id do
      movement_date =
        case sale.date do
          %DateTime{} = datetime -> DateTime.to_naive(datetime)
          %NaiveDateTime{} = naive -> naive
          _ -> NaiveDateTime.utc_now()
        end

      items
      |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
        case item.product_id do
          nil ->
            {:cont, {:ok, acc}}

          product_id ->
            attrs = %{
              tenant_id: sale.tenant_id,
              document_no: sale.invoice_number,
              movement_type: "out",
              movement_date: movement_date,
              status: "confirmed",
              reference_type: "sale",
              reference_id: sale.id,
              product_id: product_id,
              warehouse_id: sale.warehouse_id,
              quantity: item.quantity,
              unit_price: item.unit_price,
              total_amount: item.total_amount,
              notes: "Продажба №#{sale.invoice_number}"
            }

            case Inventory.create_stock_movement(attrs) do
              {:ok, movement} -> {:cont, {:ok, [movement | acc]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
        end
      end)
      |> case do
        {:ok, movements} -> {:ok, Enum.reverse(movements)}
        {:error, reason} -> {:error, {:stock_movement_failed, reason}}
      end
    else
      {:ok, []}
    end
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] ->
        acc

      {:status, status}, acc ->
        from s in acc, where: s.status == ^status

      {:from, value}, acc ->
        case to_utc_naive(value, :start) do
          {:ok, datetime} -> from s in acc, where: s.date >= ^datetime
          :error -> acc
        end

      {:to, value}, acc ->
        case to_utc_naive(value, :end) do
          {:ok, datetime} -> from s in acc, where: s.date <= ^datetime
          :error -> acc
        end

      {:customer_id, id}, acc ->
        from s in acc, where: s.customer_id == ^id

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"

        from s in acc,
          where:
            ilike(s.invoice_number, ^pattern) or
              ilike(s.customer_name, ^pattern)

      _, acc ->
        acc
    end)
  end

  defp to_utc_naive(%NaiveDateTime{} = naive, _boundary), do: {:ok, naive}

  defp to_utc_naive(%Date{} = date, :start) do
    NaiveDateTime.new(date, ~T[00:00:00])
  end

  defp to_utc_naive(%Date{} = date, :end) do
    NaiveDateTime.new(date, ~T[23:59:59])
  end

  defp to_utc_naive(value, _), do: if(is_binary(value), do: parse_datetime(value), else: :error)

  defp parse_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> {:ok, naive}
      _ -> :error
    end
  end

  # -- Invoices --

  def list_invoices(tenant_id, opts \\ []) do
    query =
      from i in Invoice,
        where: i.tenant_id == ^tenant_id,
        order_by: [desc: i.issue_date],
        preload: [:contact]

    Repo.all(apply_invoice_filters(query, opts))
  end

  def get_invoice!(tenant_id, id, preloads \\ [:contact, :invoice_lines]) do
    Invoice
    |> where([i], i.tenant_id == ^tenant_id and i.id == ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  def create_invoice(attrs) do
    attrs_with_number = maybe_generate_invoice_number(attrs)

    %Invoice{}
    |> Invoice.changeset(attrs_with_number)
    |> Repo.insert()
  end

  # Генерира автоматично номер на фактура, ако не е зададен
  defp maybe_generate_invoice_number(%{"invoice_no" => invoice_no} = attrs)
       when not is_nil(invoice_no) and invoice_no != "" do
    attrs
  end

  defp maybe_generate_invoice_number(%{invoice_no: invoice_no} = attrs)
       when not is_nil(invoice_no) and invoice_no != "" do
    attrs
  end

  defp maybe_generate_invoice_number(attrs) do
    tenant_id = attrs["tenant_id"] || attrs[:tenant_id]
    vat_document_type = attrs["vat_document_type"] || attrs[:vat_document_type]

    if tenant_id do
      case generate_invoice_number_by_type(tenant_id, vat_document_type) do
        {:ok, number} -> Map.put(attrs, "invoice_no", number)
        _ -> attrs
      end
    else
      attrs
    end
  end

  # Определя кой тип номерация да използва според вида документ
  defp generate_invoice_number_by_type(tenant_id, vat_document_type)
       when vat_document_type in ["09", "29", "50", "91", "92", "93", "94", "95"] do
    # Протоколи ВОП и други протоколи - отделна номерация
    DocumentNumbering.next_vop_protocol_number(tenant_id)
  end

  defp generate_invoice_number_by_type(tenant_id, _vat_document_type) do
    # Фактури, ДИ, КИ и други документи - стандартна номерация
    DocumentNumbering.next_sales_invoice_number(tenant_id)
  end

  def create_invoice_with_lines(invoice_attrs, lines_attrs) when is_list(lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, invoice} <- create_invoice(invoice_attrs),
           {:ok, lines} <- insert_invoice_lines(invoice, lines_attrs),
           {:ok, updated_invoice} <- update_invoice_totals(invoice, lines) do
        Repo.preload(updated_invoice, [:contact, :invoice_lines])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_invoice(%Invoice{} = invoice, attrs) do
    invoice
    |> Invoice.changeset(attrs)
    |> Repo.update()
  end

  def update_invoice_with_lines(%Invoice{} = invoice, invoice_attrs, lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, updated_invoice} <- update_invoice(invoice, invoice_attrs),
           {:ok, lines} <- replace_invoice_lines(updated_invoice, lines_attrs),
           {:ok, final_invoice} <- update_invoice_totals(updated_invoice, lines) do
        Repo.preload(final_invoice, [:contact, :invoice_lines])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Издава фактура (променя статуса на "issued") и автоматично я регистрира в ДДС дневник продажби.
  """
  def issue_invoice(%Invoice{status: "draft"} = invoice) do
    Repo.transaction(fn ->
      # Промени статуса на issued
      case update_invoice(invoice, %{status: "issued"}) do
        {:ok, updated_invoice} ->
          # Автоматично регистрирай в ДДС дневник продажби
          case Vat.register_invoice_sale(updated_invoice) do
            {:ok, _vat_entry} ->
              updated_invoice

            {:error, reason} ->
              Repo.rollback({:vat_registration_failed, reason})
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def issue_invoice(%Invoice{} = _invoice) do
    {:error, :invoice_not_draft}
  end

  @doc """
  Маркира фактура като платена и автоматично я регистрира в ДДС ако не е регистрирана.
  """
  def mark_invoice_paid(%Invoice{} = invoice) do
    Repo.transaction(fn ->
      case update_invoice(invoice, %{status: "paid", paid_amount: invoice.total_amount}) do
        {:ok, updated_invoice} ->
          # Автоматично регистрирай в ДДС ако още не е
          case Vat.register_invoice_sale(updated_invoice) do
            {:ok, _vat_entry} ->
              updated_invoice

            {:error, _reason} ->
              # Ако вече е регистрирана, игнорирай грешката
              updated_invoice
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Връща фактура към статус "чернова" (draft) и премахва регистрацията ѝ от ДДС дневник продажби.
  """
  def revert_invoice_to_draft(%Invoice{status: status} = invoice)
      when status in ["issued", "paid", "partially_paid", "overdue"] do
    Repo.transaction(fn ->
      # Намери и изтрий ДДС регистрацията ако има такава
      vat_entry = Vat.get_sales_register_by_invoice(invoice.id)

      if vat_entry do
        case Vat.delete_sales_register_entry(vat_entry) do
          {:ok, _} -> :ok
          {:error, reason} -> Repo.rollback({:vat_deletion_failed, reason})
        end
      end

      # Промени статуса на draft
      case update_invoice(invoice, %{status: "draft", paid_amount: Decimal.new(0)}) do
        {:ok, updated_invoice} -> updated_invoice
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def revert_invoice_to_draft(%Invoice{status: "draft"} = _invoice) do
    {:error, :invoice_already_draft}
  end

  def delete_invoice(%Invoice{} = invoice), do: Repo.delete(invoice)

  def change_invoice(%Invoice{} = invoice, attrs \\ %{}) do
    Invoice.changeset(invoice, attrs)
  end

  defp insert_invoice_lines(%Invoice{} = invoice, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.put(attrs, :tenant_id, invoice.tenant_id)
      attrs = Map.put(attrs, :invoice_id, invoice.id)

      %InvoiceLine{}
      |> InvoiceLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp update_invoice_totals(%Invoice{} = invoice, lines) do
    subtotal =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.subtotal)
      end)

    tax_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.tax_amount)
      end)

    total_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.total_amount)
      end)

    update_invoice(invoice, %{
      subtotal: subtotal,
      tax_amount: tax_amount,
      total_amount: total_amount
    })
  end

  defp replace_invoice_lines(%Invoice{} = invoice, lines_attrs) do
    # Първо изтриваме съществуващите редове
    Repo.delete_all(from(l in InvoiceLine, where: l.invoice_id == ^invoice.id))

    # След това вмъкваме новите
    insert_invoice_lines(invoice, lines_attrs)
  end

  defp apply_invoice_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] ->
        acc

      {:status, status}, acc ->
        from i in acc, where: i.status == ^status

      {:invoice_type, type}, acc when type in [nil, ""] ->
        acc

      {:invoice_type, type}, acc ->
        from i in acc, where: i.invoice_type == ^type

      {:contact_id, id}, acc when is_integer(id) ->
        from i in acc, where: i.contact_id == ^id

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from i in acc, where: i.issue_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from i in acc, where: i.issue_date <= ^date
          _ -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"
        from i in acc, where: ilike(i.invoice_no, ^pattern) or ilike(i.billing_name, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Invoice Lines --

  def list_invoice_lines(invoice_id) do
    Repo.all(
      from il in InvoiceLine,
        where: il.invoice_id == ^invoice_id,
        order_by: [asc: :line_no],
        preload: [:product]
    )
  end

  # -- Quotations --

  def list_quotations(tenant_id, opts \\ []) do
    query =
      from q in Quotation,
        where: q.tenant_id == ^tenant_id,
        order_by: [desc: q.issue_date],
        preload: [:contact]

    Repo.all(apply_quotation_filters(query, opts))
  end

  def get_quotation!(tenant_id, id, preloads \\ [:contact, :quotation_lines]) do
    Quotation
    |> where([q], q.tenant_id == ^tenant_id and q.id == ^id)
    |> preload(^preloads)
    |> Repo.one!()
  end

  def create_quotation(attrs) do
    %Quotation{}
    |> Quotation.changeset(attrs)
    |> Repo.insert()
  end

  def create_quotation_with_lines(quotation_attrs, lines_attrs) when is_list(lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, quotation} <- create_quotation(quotation_attrs),
           {:ok, lines} <- insert_quotation_lines(quotation, lines_attrs),
           {:ok, updated_quotation} <- update_quotation_totals(quotation, lines) do
        Repo.preload(updated_quotation, [:contact, :quotation_lines])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_quotation(%Quotation{} = quotation, attrs) do
    quotation
    |> Quotation.changeset(attrs)
    |> Repo.update()
  end

  def delete_quotation(%Quotation{} = quotation), do: Repo.delete(quotation)

  def convert_quotation_to_invoice(%Quotation{} = quotation) do
    Repo.transaction(fn ->
      # Зареди редовете
      quotation = Repo.preload(quotation, :quotation_lines)

      # Създай фактура от офертата
      invoice_attrs = %{
        tenant_id: quotation.tenant_id,
        contact_id: quotation.contact_id,
        billing_name: quotation.contact_name,
        issue_date: Date.utc_today(),
        subtotal: quotation.subtotal,
        tax_amount: quotation.tax_amount,
        total_amount: quotation.total_amount,
        currency: quotation.currency
      }

      # Преобразувай редовете
      lines_attrs =
        Enum.map(quotation.quotation_lines, fn line ->
          %{
            product_id: line.product_id,
            line_no: line.line_no,
            description: line.description,
            quantity: line.quantity,
            unit_of_measure: line.unit_of_measure,
            unit_price: line.unit_price,
            discount_percent: line.discount_percent,
            subtotal: line.subtotal,
            tax_rate: line.tax_rate,
            tax_amount: line.tax_amount,
            total_amount: line.total_amount
          }
        end)

      case create_invoice_with_lines(invoice_attrs, lines_attrs) do
        {:ok, invoice} ->
          # Обнови офертата
          update_quotation(quotation, %{status: "accepted", invoice_id: invoice.id})
          invoice

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp insert_quotation_lines(%Quotation{} = quotation, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.put(attrs, :tenant_id, quotation.tenant_id)
      attrs = Map.put(attrs, :quotation_id, quotation.id)

      %QuotationLine{}
      |> QuotationLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp update_quotation_totals(%Quotation{} = quotation, lines) do
    subtotal =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.subtotal)
      end)

    tax_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.tax_amount)
      end)

    total_amount =
      Enum.reduce(lines, Decimal.new(0), fn line, acc ->
        Decimal.add(acc, line.total_amount)
      end)

    update_quotation(quotation, %{
      subtotal: subtotal,
      tax_amount: tax_amount,
      total_amount: total_amount
    })
  end

  defp apply_quotation_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] ->
        acc

      {:status, status}, acc ->
        from q in acc, where: q.status == ^status

      {:contact_id, id}, acc when is_integer(id) ->
        from q in acc, where: q.contact_id == ^id

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from q in acc, where: q.issue_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from q in acc, where: q.issue_date <= ^date
          _ -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"
        from q in acc, where: ilike(q.quotation_no, ^pattern) or ilike(q.contact_name, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Quotation Lines --

  def list_quotation_lines(quotation_id) do
    Repo.all(
      from ql in QuotationLine,
        where: ql.quotation_id == ^quotation_id,
        order_by: [asc: :line_no],
        preload: [:product]
    )
  end

  # -- Helper functions --

  defp handle_batch_result(results) do
    case Enum.split_with(results, fn
           {:ok, _} -> true
           _ -> false
         end) do
      {oks, []} -> {:ok, Enum.map(oks, fn {:ok, record} -> record end)}
      {_, [{:error, changeset} | _]} -> {:error, changeset}
    end
  end

  def get_oss_vat_rate(country_code) do
    case Repo.get(OssVatRate, country_code) do
      nil -> Decimal.new(0)
      vat_rate -> vat_rate.rate
    end
  end

  def get_oss_sales_report(tenant_id, opts \\ []) do
    query =
      from(i in Invoice,
        where: i.tenant_id == ^tenant_id and not is_nil(i.oss_country) and i.status != "draft",
        group_by: i.oss_country,
        select: {
          i.oss_country,
          sum(i.subtotal),
          sum(i.tax_amount)
        }
      )

    query = apply_oss_filters(query, opts)

    query
    |> Repo.all()
    |> Enum.map(fn {country_code, net_amount, tax_amount} ->
      %{
        country_code: country_code,
        net_amount: net_amount,
        tax_amount: tax_amount
      }
    end)
  end

  defp apply_oss_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from i in acc, where: i.issue_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from i in acc, where: i.issue_date <= ^date
          _ -> acc
        end

      _, acc ->
        acc
    end)
  end
end
