defmodule CyberCore.DocumentProcessing.ContactProductMapping do
  @moduledoc """
  Schema for mapping supplier/contact nomenclature to our products.

  Each contact (supplier) can have their own way of describing products.
  This module stores mappings from vendor descriptions to our products,
  learning over time and increasing confidence with repeated usage.

  ## Examples

      # First time: Manual mapping
      ИНФОРМЕЙТ ЕООД says "Счетоводни услуги" → manually map to Product #123

      # Second time: Auto-select (confidence >= 80%)
      ИНФОРМЕЙТ ЕООД says "Счетоводни услуги" again → auto-select Product #123

      # Different contact, different description, same product
      ABC Ltd says "Accounting Services" → manually map to Product #123
      XYZ Corp says "Счет. консултации" → manually map to Product #123
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Contacts.Contact
  alias CyberCore.Inventory.Product
  alias CyberCore.Accounts.User

  @type t :: %__MODULE__{
          id: integer(),
          tenant_id: integer(),
          contact_id: integer(),
          vendor_description: String.t(),
          product_id: integer(),
          times_used: integer(),
          last_used_at: DateTime.t(),
          confidence: Decimal.t(),
          created_by_id: integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          contact: Contact.t() | Ecto.Association.NotLoaded.t(),
          product: Product.t() | Ecto.Association.NotLoaded.t(),
          created_by: User.t() | Ecto.Association.NotLoaded.t()
        }

  schema "contact_product_mappings" do
    field :vendor_description, :string
    field :times_used, :integer, default: 1
    field :last_used_at, :utc_datetime
    field :confidence, :decimal, default: Decimal.new("50.0")

    belongs_to :tenant, Tenant
    belongs_to :contact, Contact
    belongs_to :product, Product
    belongs_to :created_by, User

    timestamps()
  end

  @doc false
  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [
      :tenant_id,
      :contact_id,
      :vendor_description,
      :product_id,
      :times_used,
      :last_used_at,
      :confidence,
      :created_by_id
    ])
    |> validate_required([
      :tenant_id,
      :contact_id,
      :vendor_description,
      :product_id
    ])
    |> trim_vendor_description()
    |> validate_length(:vendor_description, min: 1, max: 5000)
    |> validate_number(:times_used, greater_than_or_equal_to: 1)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(
      [:tenant_id, :contact_id, :vendor_description],
      name: :contact_product_mappings_unique_mapping,
      message: "Mapping already exists for this contact and description"
    )
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:created_by_id)
    |> set_last_used_at()
  end

  defp trim_vendor_description(changeset) do
    case get_change(changeset, :vendor_description) do
      nil -> changeset
      description -> put_change(changeset, :vendor_description, String.trim(description))
    end
  end

  defp set_last_used_at(changeset) do
    if get_change(changeset, :last_used_at) == nil do
      put_change(changeset, :last_used_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
