defmodule CyberWeb.PurchaseOrderController do
  use CyberWeb, :controller

  alias CyberCore.Purchase
  alias CyberCore.Purchase.PurchaseOrder

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък с поръчки за покупка за текущия tenant.
  Поддържа филтриране по статус, доставчик, дати и търсене.

  ## Примери

      GET /api/purchase_orders
      GET /api/purchase_orders?status=pending
      GET /api/purchase_orders?supplier_id=1
      GET /api/purchase_orders?from=2025-01-01&to=2025-12-31
      GET /api/purchase_orders?search=PO-2025
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    purchase_orders = Purchase.list_purchase_orders(tenant_id, opts)
    render(conn, :index, purchase_orders: purchase_orders)
  end

  @doc """
  Създаване на нова поръчка за покупка с редове.

  ## Примери

      POST /api/purchase_orders
      {
        "purchase_order": {
          "supplier_id": 1,
          "order_no": "PO-2025-002",
          "order_date": "2025-10-11",
          "supplier_name": "Доставчик ООД"
        },
        "lines": [
          {
            "product_id": 1,
            "description": "Продукт 1",
            "quantity": "100.00",
            "unit_price": "30.00",
            "tax_rate": "20.00"
          }
        ]
      }
  """
  def create(conn, %{"purchase_order" => po_params} = params) do
    tenant_id = conn.assigns.tenant_id
    po_attrs = Map.put(po_params, "tenant_id", tenant_id)
    lines_attrs = Map.get(params, "lines", [])

    with {:ok, %PurchaseOrder{} = po} <-
           Purchase.create_purchase_order_with_lines(po_attrs, lines_attrs) do
      # Презареждаме с редовете
      po = Purchase.get_purchase_order!(tenant_id, po.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/purchase_orders/#{po}")
      |> render(:show, purchase_order: po)
    end
  end

  @doc """
  Извличане на една поръчка за покупка по ID (с редовете).
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    purchase_order = Purchase.get_purchase_order!(tenant_id, id)
    render(conn, :show, purchase_order: purchase_order)
  end

  @doc """
  Актуализиране на поръчка за покупка (без редовете).
  За редовете използвайте отделен endpoint.
  """
  def update(conn, %{"id" => id, "purchase_order" => po_params}) do
    tenant_id = conn.assigns.tenant_id
    purchase_order = Purchase.get_purchase_order!(tenant_id, id)

    with {:ok, %PurchaseOrder{} = po} <- Purchase.update_purchase_order(purchase_order, po_params) do
      po = Purchase.get_purchase_order!(tenant_id, po.id)
      render(conn, :show, purchase_order: po)
    end
  end

  @doc """
  Изтриване на поръчка за покупка.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    purchase_order = Purchase.get_purchase_order!(tenant_id, id)

    with {:ok, %PurchaseOrder{}} <- Purchase.delete_purchase_order(purchase_order) do
      send_resp(conn, :no_content, "")
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:supplier_id, params["supplier_id"])
    |> maybe_add_filter(:from, params["from"])
    |> maybe_add_filter(:to, params["to"])
    |> maybe_add_filter(:search, params["search"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, key, value) when key in [:status, :from, :to, :search] do
    [{key, value} | opts]
  end

  defp maybe_add_filter(opts, :supplier_id, value) do
    case Integer.parse(value) do
      {id, ""} -> [{:supplier_id, id} | opts]
      _ -> opts
    end
  end

  defp maybe_add_filter(opts, _key, _value), do: opts
end
