defmodule CyberCore.Sales.PriceListItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "price_list_items" do
    field :price, :decimal

    belongs_to :price_list, CyberCore.Sales.PriceList
    belongs_to :product, CyberCore.Inventory.Product

    timestamps()
  end

  @doc false
  def changeset(price_list_item, attrs) do
    price_list_item
    |> cast(attrs, [:price, :price_list_id, :product_id])
    |> validate_required([:price, :price_list_id, :product_id])
    |> unique_constraint([:price_list_id, :product_id], name: :price_list_items_price_list_id_product_id_index)
  end
end
