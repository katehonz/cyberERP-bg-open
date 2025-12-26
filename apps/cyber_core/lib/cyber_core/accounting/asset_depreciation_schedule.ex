defmodule CyberCore.Accounting.AssetDepreciationSchedule do
  @moduledoc """
  График за амортизация на дълготраен актив.

  Поддържа отделни суми за счетоводна и данъчна амортизация.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.{Asset, JournalEntry}
  alias CyberCore.Accounts.Tenant
  alias Decimal

  @depreciation_types ["accounting", "tax"]
  @statuses ["planned", "posted", "skipped"]

  schema "asset_depreciation_schedules" do
    belongs_to :tenant, Tenant
    belongs_to :asset, Asset
    belongs_to :journal_entry, JournalEntry

    field :period_date, :date
    field :amount, :decimal, default: Decimal.new(0)
    field :status, :string, default: "planned"

    # Enhanced fields for separate accounting and tax depreciation
    field :depreciation_type, :string, default: "accounting"
    field :accounting_amount, :decimal
    field :tax_amount, :decimal
    field :accumulated_depreciation, :decimal
    field :book_value, :decimal

    timestamps()
  end

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :tenant_id,
      :asset_id,
      :journal_entry_id,
      :period_date,
      :amount,
      :status,
      :depreciation_type,
      :accounting_amount,
      :tax_amount,
      :accumulated_depreciation,
      :book_value
    ])
    |> validate_required([:tenant_id, :asset_id, :period_date, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:depreciation_type, @depreciation_types)
    |> validate_positive_amount(:amount)
    |> validate_positive_amount(:accounting_amount)
    |> validate_positive_amount(:tax_amount)
    |> validate_positive_amount(:accumulated_depreciation)
    |> validate_positive_amount(:book_value)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:journal_entry_id)
  end

  defp validate_positive_amount(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        is_nil(value) -> []
        Decimal.compare(value, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [{field, "не може да е отрицателна"}]
      end
    end)
  end

  @doc """
  Проверява дали графикът е постнат
  """
  def posted?(%__MODULE__{status: "posted"}), do: true
  def posted?(_), do: false

  @doc """
  Проверява дали графикът е планиран
  """
  def planned?(%__MODULE__{status: "planned"}), do: true
  def planned?(_), do: false
end
