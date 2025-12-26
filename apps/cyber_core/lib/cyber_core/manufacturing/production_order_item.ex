defmodule CyberCore.Manufacturing.ProductionOrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product
  alias CyberCore.Manufacturing.ProductionOrder

  schema "production_order_items" do
    field :tenant_id, :integer
    belongs_to :production_order, ProductionOrder
    belongs_to :product, Product

    field :description, :string
    field :quantity, :decimal
    field :unit, :string

    timestamps()
  end

  @doc false
  def changeset(production_order_item, attrs) do
    production_order_item
    |> cast(attrs, [:tenant_id, :production_order_id, :product_id, :description, :quantity, :unit])
    |> validate_required([:tenant_id, :production_order_id, :product_id, :quantity])
  end
end
