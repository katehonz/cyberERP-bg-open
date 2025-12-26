defmodule CyberCore.Accounting.VatOperationCode do
  @moduledoc """
  VAT operation codes based on commercial product configuration and ППЗДДС.
  Maps detailed operation codes to NAP column classifications.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "vat_operation_codes" do
    field :code, :string
    field :register_type, :string
    field :description, :string
    field :column_code, :string
    field :tax_rate, :decimal
    field :deductible_credit_type, :string
    field :vies_applicable, :boolean, default: false
    field :vies_indicator, :string
    field :is_reverse_charge, :boolean, default: false
    field :allowed_subcodes, {:array, :string}
    field :is_active, :boolean, default: true
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(vat_operation_code, attrs) do
    vat_operation_code
    |> cast(attrs, [
      :code,
      :register_type,
      :description,
      :column_code,
      :tax_rate,
      :deductible_credit_type,
      :vies_applicable,
      :vies_indicator,
      :is_reverse_charge,
      :allowed_subcodes,
      :is_active,
      :notes
    ])
    |> validate_required([:code, :register_type, :description, :column_code])
    |> validate_inclusion(:register_type, ["purchase", "sale"])
    |> validate_inclusion(:deductible_credit_type, ["full", "partial", "none", "not_applicable"])
    |> validate_inclusion(:vies_indicator, ["к3", "к4", "к5", nil])
    |> unique_constraint([:code, :register_type])
  end

  @doc """
  Returns all active purchase operation codes.
  """
  def purchase_codes(query \\ __MODULE__) do
    import Ecto.Query
    from v in query, where: v.register_type == "purchase" and v.is_active == true
  end

  @doc """
  Returns all active sales operation codes.
  """
  def sale_codes(query \\ __MODULE__) do
    import Ecto.Query
    from v in query, where: v.register_type == "sale" and v.is_active == true
  end

  @doc """
  Gets operation code by code string and register type.
  """
  def get_by_code(code, register_type) do
    import Ecto.Query

    from(v in __MODULE__,
      where: v.code == ^code and v.register_type == ^register_type and v.is_active == true
    )
  end
end
