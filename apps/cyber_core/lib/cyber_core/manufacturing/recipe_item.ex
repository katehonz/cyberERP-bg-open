defmodule CyberCore.Manufacturing.RecipeItem do
  @moduledoc """
  Суровина/компонент в производствена рецепта.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product
  alias CyberCore.Manufacturing.Recipe
  alias Decimal, as: D

  schema "recipe_items" do
    field :tenant_id, :integer
    belongs_to :recipe, Recipe
    belongs_to :product, Product

    field :line_no, :integer
    field :description, :string
    field :quantity, :decimal
    field :unit, :string, default: "бр."
    field :wastage_percent, :decimal, default: D.new(0)
    field :cost, :decimal, default: D.new(0)
    field :notes, :string

    timestamps()
  end

  @required_fields ~w(tenant_id recipe_id product_id quantity)a
  @optional_fields ~w(line_no description unit wastage_percent notes cost)a

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:wastage_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:cost, greater_than_or_equal_to: 0)
    |> validate_length(:unit, max: 20)
    |> foreign_key_constraint(:recipe_id)
    |> foreign_key_constraint(:product_id)
  end
end
