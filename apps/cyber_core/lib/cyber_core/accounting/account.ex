defmodule CyberCore.Accounting.Account do
  @moduledoc """
  Сметка от сметкоплана.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @account_types [:asset, :liability, :equity, :revenue, :expense]
  @vat_directions [:none, :input, :output, :both]

  schema "accounts" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :standard_code, :string
    field :account_type, Ecto.Enum, values: @account_types
    field :account_class, :integer
    field :level, :integer, default: 1
    field :is_vat_applicable, :boolean, default: false
    field :vat_direction, Ecto.Enum, values: @vat_directions, default: :none
    field :is_active, :boolean, default: true
    field :is_analytical, :boolean, default: false
    field :supports_quantities, :boolean, default: false
    field :default_unit, :string
    field :opening_balance, :decimal, default: 0 # Начално салдо за сметката
    
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :entry_lines, CyberCore.Accounting.EntryLine

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :standard_code,
      :account_type,
      :account_class,
      :parent_id,
      :level,
      :is_vat_applicable,
      :vat_direction,
      :is_active,
      :is_analytical,
      :supports_quantities,
      :default_unit,
      :opening_balance
    ])
    |> validate_required([:tenant_id, :code, :name, :account_type, :account_class])
    |> validate_inclusion(:account_class, 1..7)
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint([:tenant_id, :code])
  end

  def debit_account?(%__MODULE__{account_type: type}), do: type in [:asset, :expense]

  def credit_account?(%__MODULE__{account_type: type}),
    do: type in [:liability, :equity, :revenue]
end
