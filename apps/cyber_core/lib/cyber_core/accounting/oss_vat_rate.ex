defmodule CyberCore.Accounting.OssVatRate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:country_code, :string, []}
  schema "oss_vat_rates" do
    field :rate, :decimal
    field :country_name, :string

    timestamps()
  end

  def changeset(vat_rate, attrs) do
    vat_rate
    |> cast(attrs, [:country_code, :rate, :country_name])
    |> validate_required([:country_code, :rate, :country_name])
    |> validate_length(:country_code, is: 2)
    |> unique_constraint(:country_code)
  end
end
