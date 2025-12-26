defmodule CyberCore.Accounting.FinancialAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Accounting.{Account, FinancialTransaction}

  schema "financial_accounts" do
    belongs_to :tenant, Tenant
    belongs_to :account, Account

    field :name, :string
    field :kind, :string
    field :currency, :string, default: "BGN"
    field :organization_unit, :string
    field :is_active, :boolean, default: true
    field :metadata, :map

    has_many :transactions, FinancialTransaction

    timestamps()
  end

  def changeset(financial_account, attrs) do
    financial_account
    |> cast(attrs, [
      :tenant_id,
      :account_id,
      :name,
      :kind,
      :currency,
      :organization_unit,
      :is_active,
      :metadata
    ])
    |> validate_required([:tenant_id, :name, :kind, :currency])
    |> validate_inclusion(:kind, ["cash", "bank", "card", "other"])
    |> unique_constraint(:name, name: :financial_accounts_tenant_id_name_index)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:account_id)
  end
end
