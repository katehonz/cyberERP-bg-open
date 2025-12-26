defmodule CyberCore.Manufacturing.Recipe do
  @moduledoc """
  Производствена рецепта (Bill of Materials) за крайни продукти.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product
  alias Decimal

  schema "recipes" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :description, :string
    field :output_quantity, :decimal, default: Decimal.new(1)
    field :unit, :string, default: "бр."
    field :version, :string, default: "1.0"
    field :is_active, :boolean, default: true
    field :notes, :string
    field :production_cost, :decimal, default: Decimal.new(0)

    belongs_to :output_product, Product
    has_many :recipe_items, CyberCore.Manufacturing.RecipeItem

    timestamps()
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :description,
      :output_product_id,
      :output_quantity,
      :unit,
      :version,
      :is_active,
      :notes,
      :production_cost
    ])
    |> validate_required([:tenant_id, :code, :name, :output_quantity])
    |> validate_number(:output_quantity, greater_than: 0)
    |> validate_number(:production_cost, greater_than_or_equal_to: 0)
    |> validate_length(:code, max: 50)
    |> validate_length(:name, max: 120)
    |> validate_length(:unit, max: 20)
    |> unique_constraint(:code, name: :recipes_tenant_id_code_index)
    |> foreign_key_constraint(:output_product_id)
  end
end
