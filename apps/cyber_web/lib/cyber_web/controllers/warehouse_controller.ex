defmodule CyberWeb.WarehouseController do
  use CyberWeb, :controller

  alias CyberCore.Inventory
  alias CyberCore.Inventory.Warehouse

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък със складове за текущия tenant.
  Поддържа филтриране по is_active.

  ## Примери

      GET /api/warehouses
      GET /api/warehouses?is_active=true
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    warehouses = Inventory.list_warehouses(tenant_id, opts)
    render(conn, :index, warehouses: warehouses)
  end

  @doc """
  Създаване на нов склад.
  """
  def create(conn, %{"warehouse" => warehouse_params}) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.put(warehouse_params, "tenant_id", tenant_id)

    with {:ok, %Warehouse{} = warehouse} <- Inventory.create_warehouse(attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/warehouses/#{warehouse}")
      |> render(:show, warehouse: warehouse)
    end
  end

  @doc """
  Извличане на един склад по ID.
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    warehouse = Inventory.get_warehouse!(tenant_id, id)
    render(conn, :show, warehouse: warehouse)
  end

  @doc """
  Актуализиране на склад.
  """
  def update(conn, %{"id" => id, "warehouse" => warehouse_params}) do
    tenant_id = conn.assigns.tenant_id
    warehouse = Inventory.get_warehouse!(tenant_id, id)

    with {:ok, %Warehouse{} = warehouse} <-
           Inventory.update_warehouse(warehouse, warehouse_params) do
      render(conn, :show, warehouse: warehouse)
    end
  end

  @doc """
  Изтриване на склад.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    warehouse = Inventory.get_warehouse!(tenant_id, id)

    with {:ok, %Warehouse{}} <- Inventory.delete_warehouse(warehouse) do
      send_resp(conn, :no_content, "")
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:is_active, params["is_active"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, :is_active, value) when value in ["true", "false"] do
    [{:is_active, value == "true"} | opts]
  end

  defp maybe_add_filter(opts, _key, _value), do: opts
end
