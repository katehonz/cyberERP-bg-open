defmodule CyberCore.Sales.PriceList do
  use Ecto.Schema
  import Ecto.Changeset

  @type_enums ["retail", "non_retail"]

  schema "price_lists" do
    field :name, :string
    field :type, :string, default: "non_retail"

    belongs_to :tenant, CyberCore.Accounts.Tenant
    belongs_to :currency, CyberCore.Currencies.Currency
    has_many :price_list_items, CyberCore.Sales.PriceListItem, on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(price_list, attrs) do
    price_list
    |> cast(attrs, [:name, :type, :tenant_id, :currency_id])
    |> validate_required([:name, :type, :tenant_id, :currency_id])
    |> validate_inclusion(:type, @type_enums)
    |> unique_constraint(:name, name: :price_lists_tenant_id_name_index)
  end
end
