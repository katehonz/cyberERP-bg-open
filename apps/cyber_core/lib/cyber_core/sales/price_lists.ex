defmodule CyberCore.Sales.PriceLists do
  @moduledoc """
  The context for managing Price Lists.
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo

  alias CyberCore.Sales.PriceList

  def list_price_lists(tenant_id) do
    from(p in PriceList, where: p.tenant_id == ^tenant_id, order_by: [asc: :name])
    |> Repo.all()
  end

  def get_price_list(id) when is_binary(id) do
    Repo.get(PriceList, id)
  end
  def get_price_list(nil), do: nil

  def get_price_list!(id, preload_items \\ false) do
    query = from(p in PriceList, where: p.id == ^id)
    query = if preload_items, do: from(p in query, preload: [:price_list_items]), else: query
    Repo.one!(query)
  end

  def create_price_list(attrs \\ %{}) do
    %PriceList{}
    |> PriceList.changeset(attrs)
    |> Repo.insert()
  end

  def update_price_list(%PriceList{} = price_list, attrs) do
    price_list
    |> PriceList.changeset(attrs)
    |> Repo.update()
  end

  def delete_price_list(%PriceList{} = price_list) do
    Repo.delete(price_list)
  end

  alias CyberCore.Sales.PriceListItem

  def list_price_list_items(price_list_id) do
      from(i in PriceListItem, where: i.price_list_id == ^price_list_id)
      |> Repo.all()
      |> Repo.preload(:product)
  end

  def get_price_list_item!(id) do
    Repo.get!(PriceListItem, id)
  end

  def get_item_by_product(price_list_id, product_id) do
    from(i in PriceListItem, where: i.price_list_id == ^price_list_id and i.product_id == ^product_id)
    |> Repo.one()
  end

  def create_price_list_item(attrs \\ %{}) do
    %PriceListItem{}
    |> PriceListItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_price_list_item(%PriceListItem{} = item, attrs) do
    item
    |> PriceListItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_price_list_item(%PriceListItem{} = item) do
    Repo.delete(item)
  end
end
