defmodule CyberCore.Sales.QuotationLine do
  @moduledoc """
  Редове на оферта.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "quotation_lines" do
    field :tenant_id, :integer

    # Връзки
    belongs_to :quotation, CyberCore.Sales.Quotation
    belongs_to :product, CyberCore.Inventory.Product

    # Данни за реда
    field :line_no, :integer
    field :description, :string
    field :quantity, :decimal
    field :unit_of_measure, :string, default: "бр."
    field :unit_price, :decimal
    field :discount_percent, :decimal, default: Decimal.new(0)

    # Финансови данни
    field :subtotal, :decimal
    field :tax_rate, :decimal, default: Decimal.new("20.0")
    field :tax_amount, :decimal
    field :total_amount, :decimal

    # Допълнителна информация
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :tenant_id,
      :quotation_id,
      :product_id,
      :line_no,
      :description,
      :quantity,
      :unit_of_measure,
      :unit_price,
      :discount_percent,
      :subtotal,
      :tax_rate,
      :tax_amount,
      :total_amount,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :quotation_id,
      :description,
      :quantity,
      :unit_price
    ])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:discount_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> calculate_amounts()
  end

  defp calculate_amounts(changeset) do
    quantity = get_field(changeset, :quantity)
    unit_price = get_field(changeset, :unit_price)
    discount_percent = get_field(changeset, :discount_percent) || Decimal.new(0)
    tax_rate = get_field(changeset, :tax_rate) || Decimal.new("20.0")

    if quantity && unit_price do
      # Брутна сума
      gross_amount = Decimal.mult(quantity, unit_price)

      # Отстъпка
      discount_amount =
        gross_amount
        |> Decimal.mult(discount_percent)
        |> Decimal.div(Decimal.new(100))

      # Нетна сума (без ДДС)
      subtotal = Decimal.sub(gross_amount, discount_amount)

      # ДДС
      tax_amount =
        subtotal
        |> Decimal.mult(tax_rate)
        |> Decimal.div(Decimal.new(100))

      # Обща сума
      total_amount = Decimal.add(subtotal, tax_amount)

      changeset
      |> put_change(:subtotal, subtotal)
      |> put_change(:tax_amount, tax_amount)
      |> put_change(:total_amount, total_amount)
    else
      changeset
    end
  end
end
