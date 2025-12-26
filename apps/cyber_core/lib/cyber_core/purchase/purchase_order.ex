defmodule CyberCore.Purchase.PurchaseOrder do
  @moduledoc """
  Поръчки за покупка към доставчици.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft sent confirmed receiving received cancelled)

  schema "purchase_orders" do
    field :tenant_id, :integer

    # Номериране
    field :order_no, :string
    field :status, :string, default: "draft"

    # Дати
    field :order_date, :date
    field :expected_date, :date
    field :received_date, :date

    # Връзки
    belongs_to :supplier, CyberCore.Contacts.Contact
    field :supplier_name, :string
    field :supplier_address, :string
    field :supplier_vat_number, :string

    # Финансови данни
    field :subtotal, :decimal, default: Decimal.new(0)
    field :tax_amount, :decimal, default: Decimal.new(0)
    field :total_amount, :decimal, default: Decimal.new(0)
    field :currency, :string, default: "BGN"

    # Допълнителна информация
    field :notes, :string
    field :payment_terms, :string
    field :reference, :string

    # Редове на поръчката
    has_many :purchase_order_lines, CyberCore.Purchase.PurchaseOrderLine

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :tenant_id,
      :order_no,
      :status,
      :order_date,
      :expected_date,
      :received_date,
      :supplier_id,
      :supplier_name,
      :supplier_address,
      :supplier_vat_number,
      :subtotal,
      :tax_amount,
      :total_amount,
      :currency,
      :notes,
      :payment_terms,
      :reference
    ])
    |> validate_required([
      :tenant_id,
      :order_no,
      :order_date,
      :supplier_id,
      :supplier_name
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:order_no, max: 50)
    |> validate_length(:currency, is: 3)
    |> unique_constraint([:tenant_id, :order_no])
    |> foreign_key_constraint(:supplier_id)
  end
end
