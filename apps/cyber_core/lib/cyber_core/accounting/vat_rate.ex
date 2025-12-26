defmodule CyberCore.Accounting.VatRate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "vat_rates" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :rate, :decimal
    field :vat_direction, :string
    field :is_active, :boolean, default: true
    field :valid_from, :date
    field :valid_to, :date

    timestamps()
  end

  def changeset(rate, attrs) do
    rate
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :rate,
      :vat_direction,
      :is_active,
      :valid_from,
      :valid_to
    ])
    |> validate_required([:tenant_id, :code, :name, :rate, :vat_direction, :valid_from])
    |> unique_constraint([:tenant_id, :code])
  end
end
