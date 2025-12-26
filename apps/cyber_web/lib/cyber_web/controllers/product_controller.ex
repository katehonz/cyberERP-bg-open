defmodule CyberWeb.ProductController do
  use CyberWeb, :controller

  alias CyberCore.Inventory
  alias CyberCore.Inventory.Product

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    filters = build_filters(params)

    products = Inventory.list_products(tenant.id, filters)
    json(conn, %{data: Enum.map(products, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      product = Inventory.get_product!(tenant.id, id)
      json(conn, %{data: serialize(product)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant
    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %Product{} = product} <- Inventory.create_product(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(product)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Product{} = product <- Inventory.get_product!(tenant.id, id),
         {:ok, %Product{} = updated} <- Inventory.update_product(product, payload(params)) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Product{} = product <- Inventory.get_product!(tenant.id, id),
         {:ok, _} <- Inventory.delete_product(product) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("product", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp build_filters(params) do
    []
    |> maybe_put(:category, params["category"])
    |> maybe_put(:search, params["search"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: {:error, :not_found}

  defp serialize(%Product{} = product) do
    %{
      id: product.id,
      name: product.name,
      sku: product.sku,
      description: product.description,
      category: product.category,
      quantity: product.quantity,
      price: product.price,
      cost: product.cost,
      unit: product.unit,
      inserted_at: product.inserted_at,
      updated_at: product.updated_at
    }
  end
end
