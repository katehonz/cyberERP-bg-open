defmodule CyberCore.Sales.Sale do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Contacts.Contact
  alias CyberCore.Inventory.Warehouse
  alias Decimal

  schema "sales" do
    belongs_to :tenant, Tenant
    belongs_to :customer, Contact
    belongs_to :warehouse, Warehouse

    field :invoice_number, :string
    field :customer_name, :string
    field :customer_email, :string
    field :customer_phone, :string
    field :customer_address, :string
    field :date, :utc_datetime
    field :amount, :decimal, default: Decimal.new(0)
    field :status, :string, default: "pending"
    field :notes, :string
    field :payment_method, :string
    field :pos_reference, :string

    has_many :sale_items, CyberCore.Sales.SaleItem

    timestamps()
  end

  @doc false
  def changeset(sale, attrs) do
    sale
    |> cast(attrs, [
      :tenant_id,
      :invoice_number,
      :customer_id,
      :customer_name,
      :customer_email,
      :customer_phone,
      :customer_address,
      :date,
      :amount,
      :status,
      :notes,
      :warehouse_id,
      :payment_method,
      :pos_reference
    ])
    |> validate_required([:tenant_id, :invoice_number, :customer_name, :date, :amount])
    |> update_change(:customer_email, &normalize_email/1)
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:status, ["pending", "paid", "void", "overdue"])
    |> validate_amount()
    |> unique_constraint(:invoice_number, name: :sales_tenant_id_invoice_number_index)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:customer_id)
    |> foreign_key_constraint(:warehouse_id)
    |> validate_length(:payment_method, max: 50)
    |> validate_length(:pos_reference, max: 50)
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) do
    email
    |> String.trim()
    |> case do
      "" -> nil
      value -> String.downcase(value)
    end
  end

  defp validate_amount(changeset) do
    validate_change(changeset, :amount, fn :amount, amount ->
      cond do
        is_nil(amount) -> []
        Decimal.compare(amount, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [amount: "не може да е отрицателна"]
      end
    end)
  end
end
