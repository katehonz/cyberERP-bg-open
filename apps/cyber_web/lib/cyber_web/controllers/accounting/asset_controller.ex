defmodule CyberWeb.Accounting.AssetController do
  use CyberWeb, :controller

  alias CyberCore.Accounting
  alias CyberCore.Accounting.{Asset, FixedAssets}
  alias CyberCore.SAFT
  alias Decimal

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    filters = build_filters(params)

    assets = Accounting.list_assets(tenant.id, filters)
    json(conn, %{data: Enum.map(assets, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      asset =
        Accounting.get_asset!(tenant.id, id, [:depreciation_schedule, :transactions, :supplier])

      json(conn, %{data: serialize_with_details(asset)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %Asset{} = asset} <- Accounting.create_asset(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(asset)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Asset{} = asset <- Accounting.get_asset!(tenant.id, id),
         {:ok, %Asset{} = updated} <- Accounting.update_asset(asset, params |> payload()) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Asset{} = asset <- Accounting.get_asset!(tenant.id, id),
         {:ok, _asset} <- Accounting.delete_asset(asset) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # Увеличаване на стойността на актив
  def increase_value(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Asset{} = asset <- Accounting.get_asset!(tenant.id, id),
         attrs <- build_increase_value_attrs(params),
         {:ok, {updated_asset, transaction}} <- FixedAssets.increase_asset_value(asset, attrs) do
      json(conn, %{
        data: %{
          asset: serialize(updated_asset),
          transaction: serialize_transaction(transaction),
          message: "Стойността на актива е успешно увеличена"
        }
      })
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # Списък с транзакции за актив
  def transactions(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Asset{} = asset <- Accounting.get_asset!(tenant.id, id) do
      transactions = FixedAssets.list_asset_transactions(asset.id)
      json(conn, %{data: Enum.map(transactions, &serialize_transaction/1)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # Статистика за активи
  def statistics(conn, _params) do
    tenant = conn.assigns.current_tenant
    stats = FixedAssets.get_assets_statistics(tenant.id)
    json(conn, %{data: stats})
  end

  # Генериране на SAF-T годишен файл
  def export_saft_annual(conn, %{"year" => year}) do
    tenant = conn.assigns.current_tenant
    temp_file = "/tmp/saft_annual_#{tenant.id}_#{year}.xml"

    with {year_int, _} <- Integer.parse(year),
         {:ok, xml_content} <- SAFT.generate(:annual, tenant.id, year: year_int),
         :ok <- File.write(temp_file, xml_content) do
      conn
      |> put_resp_content_type("application/xml")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"saft_annual_#{year_int}.xml\""
      )
      |> send_file(200, temp_file)
      |> then(fn conn ->
        File.rm(temp_file)
        conn
      end)
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Грешка при генериране на SAF-T файл: #{inspect(reason)}"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Невалидна година"})
    end
  end

  # Подготовка на данни за начало на година
  def prepare_year_beginning(conn, %{"year" => year}) do
    tenant = conn.assigns.current_tenant

    with {year_int, _} <- Integer.parse(year),
         {:ok, count} <- FixedAssets.prepare_year_beginning_values(tenant.id, year_int) do
      json(conn, %{
        data: %{
          message: "Успешно подготвени началните стойности за #{count} активa",
          year: year_int,
          assets_count: count
        }
      })
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Невалидна година"})
    end
  end

  defp payload(params) do
    params
    |> Map.get("asset", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp build_filters(params) do
    []
    |> maybe_put(:status, params["status"])
    |> maybe_put(:category, params["category"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp build_increase_value_attrs(params) do
    attrs = params["increase_value"] || params

    %{
      amount: parse_decimal(attrs["amount"]),
      transaction_date: parse_date(attrs["transaction_date"]),
      description: attrs["description"],
      regenerate_schedule: attrs["regenerate_schedule"] || false
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp parse_decimal(%Decimal{} = value), do: value
  defp parse_decimal(value) when is_number(value), do: Decimal.new(to_string(value))

  defp parse_date(nil), do: nil
  defp parse_date(%Date{} = date), do: date
  defp parse_date(date) when is_binary(date), do: Date.from_iso8601!(date)

  defp serialize(%Asset{} = asset) do
    %{
      id: asset.id,
      code: asset.code,
      name: asset.name,
      category: asset.category,
      inventory_number: asset.inventory_number,
      serial_number: asset.serial_number,
      location: asset.location,
      responsible_person: asset.responsible_person,
      tax_category: asset.tax_category,
      tax_depreciation_rate: asset.tax_depreciation_rate,
      accounting_depreciation_rate: asset.accounting_depreciation_rate,
      acquisition_date: asset.acquisition_date,
      acquisition_cost: asset.acquisition_cost,
      startup_date: asset.startup_date,
      purchase_order_date: asset.purchase_order_date,
      supplier_id: asset.supplier_id,
      invoice_number: asset.invoice_number,
      invoice_date: asset.invoice_date,
      salvage_value: asset.salvage_value,
      useful_life_months: asset.useful_life_months,
      depreciation_method: asset.depreciation_method,
      status: asset.status,
      accounting_account_id: asset.accounting_account_id,
      expense_account_id: asset.expense_account_id,
      accumulated_depreciation_account_id: asset.accumulated_depreciation_account_id,
      residual_value: asset.residual_value,
      disposal_date: asset.disposal_date,
      disposal_reason: asset.disposal_reason,
      disposal_value: asset.disposal_value,
      notes: asset.notes,
      month_value_change: asset.month_value_change,
      month_suspension_resumption: asset.month_suspension_resumption,
      month_writeoff_accounting: asset.month_writeoff_accounting,
      month_writeoff_tax: asset.month_writeoff_tax,
      depreciation_months_current_year: asset.depreciation_months_current_year,
      acquisition_cost_begin_year: asset.acquisition_cost_begin_year,
      book_value_begin_year: asset.book_value_begin_year,
      accumulated_depreciation_begin_year: asset.accumulated_depreciation_begin_year,
      metadata: asset.metadata,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end

  defp serialize_with_details(%Asset{} = asset) do
    asset
    |> serialize()
    |> Map.merge(%{
      depreciation_schedule: Enum.map(asset.depreciation_schedule || [], &serialize_schedule/1),
      transactions: Enum.map(asset.transactions || [], &serialize_transaction/1),
      supplier: if(asset.supplier, do: serialize_supplier(asset.supplier), else: nil),
      accumulated_depreciation: FixedAssets.calculate_accumulated_depreciation(asset),
      book_value: FixedAssets.calculate_book_value(asset)
    })
  end

  defp serialize_schedule(schedule) do
    %{
      id: schedule.id,
      period_date: schedule.period_date,
      amount: schedule.amount,
      status: schedule.status,
      depreciation_type: schedule.depreciation_type,
      accounting_amount: schedule.accounting_amount,
      tax_amount: schedule.tax_amount,
      accumulated_depreciation: schedule.accumulated_depreciation,
      book_value: schedule.book_value
    }
  end

  defp serialize_transaction(transaction) do
    %{
      id: transaction.id,
      transaction_type: transaction.transaction_type,
      transaction_type_name:
        CyberCore.Accounting.AssetTransaction.transaction_name(transaction.transaction_type),
      transaction_date: transaction.transaction_date,
      description: transaction.description,
      transaction_amount: transaction.transaction_amount,
      acquisition_cost_change: transaction.acquisition_cost_change,
      book_value_after: transaction.book_value_after,
      year: transaction.year,
      month: transaction.month,
      inserted_at: transaction.inserted_at
    }
  end

  defp serialize_supplier(supplier) do
    %{
      id: supplier.id,
      name: supplier.name,
      registration_number: supplier.registration_number,
      vat_number: supplier.vat_number
    }
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: {:error, :not_found}
end
