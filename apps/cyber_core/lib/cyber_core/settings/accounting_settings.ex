defmodule CyberCore.Settings.AccountingSettings do
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.Account
  alias CyberCore.Accounts.Tenant

  schema "accounting_settings" do
    belongs_to :tenant, Tenant
    belongs_to :suppliers_account, Account
    belongs_to :customers_account, Account
    belongs_to :cash_account, Account
    belongs_to :vat_sales_account, Account
    belongs_to :vat_purchases_account, Account
    belongs_to :default_income_account, Account
    belongs_to :inventory_goods_account, Account
    belongs_to :inventory_materials_account, Account
    belongs_to :inventory_produced_account, Account
    belongs_to :cogs_account, Account
    belongs_to :wip_account, Account

    timestamps()
  end

  @doc false
  def changeset(accounting_settings, attrs) do
    accounting_settings
    |> cast(attrs, [
      :tenant_id,
      :suppliers_account_id,
      :customers_account_id,
      :cash_account_id,
      :vat_sales_account_id,
      :vat_purchases_account_id,
      :default_income_account_id,
      :inventory_goods_account_id,
      :inventory_materials_account_id,
      :inventory_produced_account_id,
      :cogs_account_id,
      :wip_account_id
    ])
    |> validate_required([:tenant_id])
    |> unique_constraint(:tenant_id)
  end
end
