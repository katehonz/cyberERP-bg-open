defmodule CyberWeb.SaleController do
  use CyberWeb, :controller

  alias CyberCore.Sales
  alias CyberCore.Sales.Sale

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant

    filters =
      []
      |> maybe_put(:status, params["status"])
      |> maybe_put(:customer_id, parse_optional_id(params["customer_id"]))
      |> maybe_put(:search, params["search"])
      |> maybe_put(:from, parse_optional_datetime(params["from"]))
      |> maybe_put(:to, parse_optional_datetime(params["to"]))

    sales = Sales.list_sales(tenant.id, filters)
    json(conn, %{data: Enum.map(sales, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      sale = Sales.get_sale!(tenant.id, id)
      json(conn, %{data: serialize(sale)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %Sale{} = sale} <- Sales.create_sale(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(sale)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Sale{} = sale <- Sales.get_sale!(tenant.id, id),
         {:ok, %Sale{} = updated} <- Sales.update_sale(sale, payload(params)) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Sale{} = sale <- Sales.get_sale!(tenant.id, id),
         {:ok, _} <- Sales.delete_sale(sale) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("sale", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, {:ok, value}), do: Keyword.put(filters, key, value)
  defp maybe_put(filters, _key, :error), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: {:error, :not_found}

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil

  defp parse_optional_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> :error
    end
  end

  defp parse_optional_id(id) when is_integer(id), do: {:ok, id}
  defp parse_optional_id(_), do: :error

  defp parse_optional_datetime(nil), do: nil
  defp parse_optional_datetime(""), do: nil

  defp parse_optional_datetime(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> {:ok, naive}
      _ -> :error
    end
  end

  defp parse_optional_datetime(%NaiveDateTime{} = naive), do: {:ok, naive}
  defp parse_optional_datetime(%Date{} = date), do: {:ok, NaiveDateTime.new!(date, ~T[00:00:00])}
  defp parse_optional_datetime(_), do: :error

  defp serialize(%Sale{} = sale) do
    %{
      id: sale.id,
      invoice_number: sale.invoice_number,
      customer_id: sale.customer_id,
      customer_name: sale.customer_name,
      customer_email: sale.customer_email,
      customer_phone: sale.customer_phone,
      customer_address: sale.customer_address,
      date: sale.date,
      amount: sale.amount,
      status: sale.status,
      notes: sale.notes,
      inserted_at: sale.inserted_at,
      updated_at: sale.updated_at
    }
  end
end
