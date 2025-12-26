defmodule CyberCore.Inventory.Product do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Accounting.Account
  alias CyberCore.Inventory.{CnNomenclature, ProductUnit}
  alias Decimal

  @categories ~w(goods materials services produced)
  @fields ~w(tenant_id name sku description category quantity price cost unit barcode tax_rate is_active track_inventory account_id expense_account_id revenue_account_id cn_code_id opening_quantity opening_cost)a

  schema "products" do
    belongs_to :tenant, Tenant
    # Инвентарна сметка (304 стоки, 302 материали, 303 полуфабрикати)
    belongs_to :account, Account
    # Сметка за разход/себестойност (702 стоки, 601 материали, 611 полуфабрикати)
    belongs_to :expense_account, Account
    # Сметка за приходи от продажба (702 стоки, null за материали)
    belongs_to :revenue_account, Account
    belongs_to :cn_code, CnNomenclature

    field :name, :string
    field :sku, :string
    field :description, :string
    field :category, :string
    field :quantity, :integer, default: 0
    field :price, :decimal, default: Decimal.new(0)
    field :cost, :decimal, default: Decimal.new(0)
    field :unit, :string, default: "бр."
    field :barcode, :string
    field :tax_rate, :decimal, default: Decimal.new(20)
    field :is_active, :boolean, default: true
    field :track_inventory, :boolean, default: true
    field :opening_quantity, :decimal, default: Decimal.new(0) # Начално количество за склад
    field :opening_cost, :decimal, default: Decimal.new(0)     # Начална стойност на склад

    has_many :product_units, ProductUnit

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, @fields)
    |> validate_required([:tenant_id, :name, :sku, :category])
    |> maybe_normalize(:category)
    |> validate_inclusion(:category, @categories,
      message: "трябва да бъде една от: стоки, материали, услуги, произведена продукция"
    )
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_decimal(:price)
    |> validate_decimal(:cost)
    |> validate_decimal(:tax_rate)
    |> validate_decimal(:opening_cost)
    |> validate_decimal(:opening_quantity)
    |> unique_constraint(:sku, name: :products_tenant_id_sku_index)
    |> unique_constraint(:barcode, name: :products_barcode_index)
    |> foreign_key_constraint(:tenant_id)
  end

  defp maybe_normalize(changeset, field) do
    update_change(changeset, field, fn
      nil -> nil
      value -> String.trim(value)
    end)
  end

  defp validate_decimal(changeset, field) do
    changeset
    |> validate_change(field, fn ^field, value ->
      cond do
        is_nil(value) -> []
        Decimal.compare(value, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [{field, "не може да е отрицателна"}]
      end
    end)
  end
end
