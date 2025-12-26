defmodule CyberCore.Sales.SaleItem do
  @moduledoc """
  Редове на продажба (използват се за POS и продажбени документи).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Sales.Sale
  alias CyberCore.Inventory.Product
  alias Decimal, as: D

  schema "sale_items" do
    field :tenant_id, :integer
    belongs_to :sale, Sale
    belongs_to :product, Product

    field :line_no, :integer
    field :sku, :string
    field :description, :string
    field :unit, :string, default: "бр."
    field :quantity, :decimal
    field :unit_price, :decimal
    field :discount_percent, :decimal, default: D.new(0)
    field :subtotal, :decimal
    field :tax_rate, :decimal, default: D.new("20.0")
    field :tax_amount, :decimal
    field :total_amount, :decimal
    field :notes, :string

    timestamps()
  end

  @required_fields ~w(tenant_id sale_id description quantity unit_price)a
  @optional_fields ~w(product_id line_no sku unit discount_percent subtotal tax_rate tax_amount total_amount notes)a

  @doc false
  def changeset(sale_item, attrs) do
    sale_item
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:discount_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0)
    |> calculate_amounts()
    |> foreign_key_constraint(:sale_id)
    |> foreign_key_constraint(:product_id)
  end

  defp calculate_amounts(%{valid?: false} = changeset), do: changeset

  defp calculate_amounts(changeset) do
    quantity = get_field(changeset, :quantity)
    unit_price = get_field(changeset, :unit_price)
    discount_percent = get_field(changeset, :discount_percent) || D.new(0)
    tax_rate = get_field(changeset, :tax_rate) || D.new("20.0")

    gross = D.mult(quantity, unit_price)
    discount = gross |> D.mult(discount_percent) |> D.div(D.new(100))
    subtotal = D.sub(gross, discount)
    tax_amount = subtotal |> D.mult(tax_rate) |> D.div(D.new(100))
    total_amount = D.add(subtotal, tax_amount)

    changeset
    |> put_change(:subtotal, subtotal)
    |> put_change(:tax_amount, tax_amount)
    |> put_change(:total_amount, total_amount)
  end
end
