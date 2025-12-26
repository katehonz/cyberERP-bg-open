defmodule CyberWeb.WarehouseJSON do
  @moduledoc """
  JSON сериализация за Warehouse ресурс.
  """

  alias CyberCore.Inventory.Warehouse

  @doc """
  Рендерира списък от складове.
  """
  def index(%{warehouses: warehouses}) do
    %{data: for(warehouse <- warehouses, do: data(warehouse))}
  end

  @doc """
  Рендерира един склад.
  """
  def show(%{warehouse: warehouse}) do
    %{data: data(warehouse)}
  end

  defp data(%Warehouse{} = warehouse) do
    %{
      id: warehouse.id,
      tenant_id: warehouse.tenant_id,
      code: warehouse.code,
      name: warehouse.name,
      address: warehouse.address,
      city: warehouse.city,
      postal_code: warehouse.postal_code,
      country: warehouse.country,
      is_active: warehouse.is_active,
      notes: warehouse.notes,
      inserted_at: warehouse.inserted_at,
      updated_at: warehouse.updated_at
    }
  end
end
