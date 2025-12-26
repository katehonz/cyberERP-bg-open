defmodule CyberCore.Accounting.Asset do
  @moduledoc """
  Дълготраен материален актив (ДМА) според българските счетоводни стандарти и ЗКПО.

  Поддържа:
  - 7 данъчни категории според ЗКПО
  - Разделение между счетоводна и данъчна амортизация
  - Пълна информация за придобиване и извеждане от употреба
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.{Account, AssetDepreciationSchedule, AssetTransaction, JournalEntry}
  alias CyberCore.Accounts.Tenant
  alias CyberCore.Contacts.Contact
  alias Decimal

  @tax_categories %{
    "I" => %{name: "Сгради и съоръжения", rate: 0.04},
    "II" => %{name: "Машини и оборудване", rate: 0.30},
    "III" => %{name: "Транспортни средства", rate: 0.10},
    "IV" => %{name: "Компютри и софтуер", rate: 0.50},
    "V" => %{name: "Автомобили", rate: 0.25},
    "VI" => %{name: "Активи с ограничен срок", rate: nil},
    "VII" => %{name: "Други активи", rate: 0.15}
  }

  @depreciation_methods ["straight_line", "declining_balance", "units_of_production"]
  @statuses ["active", "inactive", "disposed", "fully_depreciated"]

  schema "assets" do
    belongs_to :tenant, Tenant

    # Basic information
    field :code, :string
    field :name, :string
    field :category, :string
    field :inventory_number, :string
    field :serial_number, :string
    field :location, :string
    field :responsible_person, :string

    # Tax category (ЗКПО)
    field :tax_category, :string
    field :tax_depreciation_rate, :decimal
    field :accounting_depreciation_rate, :decimal

    # Acquisition information
    field :acquisition_date, :date
    field :acquisition_cost, :decimal
    # Дата на въвеждане в експлоатация
    field :startup_date, :date
    # Дата на поръчка
    field :purchase_order_date, :date
    belongs_to :supplier, Contact
    field :invoice_number, :string
    field :invoice_date, :date

    # Depreciation settings
    field :salvage_value, :decimal, default: Decimal.new(0)
    field :useful_life_months, :integer
    field :depreciation_method, :string

    # Status
    field :status, :string, default: "active"
    field :residual_value, :decimal, default: Decimal.new(0)

    # Accounting accounts
    # Сметка ДМА (напр. 203)
    belongs_to :accounting_account, Account
    # Сметка разходи (напр. 603)
    belongs_to :expense_account, Account
    # Сметка амортизация (напр. 2413)
    belongs_to :accumulated_depreciation_account, Account

    # Disposal information
    field :disposal_date, :date
    field :disposal_reason, :string
    field :disposal_value, :decimal
    belongs_to :disposal_journal_entry, JournalEntry

    # Additional information
    field :notes, :string
    field :attachments, :map
    field :metadata, :map

    # SAF-T specific fields for value changes tracking
    # Месец на промяна на стойността
    field :month_value_change, :integer
    # Месец на спиране/възобновяване
    field :month_suspension_resumption, :integer
    # Месец на отписване от счетоводен план
    field :month_writeoff_accounting, :integer
    # Месец на отписване от данъчен план
    field :month_writeoff_tax, :integer
    # Брой месеци амортизация през годината
    field :depreciation_months_current_year, :integer

    # Beginning of year values for SAF-T annual reporting
    field :acquisition_cost_begin_year, :decimal
    field :book_value_begin_year, :decimal
    field :accumulated_depreciation_begin_year, :decimal

    has_many :depreciation_schedule, AssetDepreciationSchedule
    has_many :transactions, AssetTransaction

    timestamps()
  end

  @doc """
  Връща списък с наличните данъчни категории според ЗКПО
  """
  def tax_categories, do: @tax_categories

  @doc """
  Връща информация за конкретна данъчна категория
  """
  def tax_category_info(category) when is_binary(category) do
    Map.get(@tax_categories, category)
  end

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :category,
      :inventory_number,
      :serial_number,
      :location,
      :responsible_person,
      :tax_category,
      :tax_depreciation_rate,
      :accounting_depreciation_rate,
      :acquisition_date,
      :acquisition_cost,
      :startup_date,
      :purchase_order_date,
      :supplier_id,
      :invoice_number,
      :invoice_date,
      :salvage_value,
      :useful_life_months,
      :depreciation_method,
      :status,
      :accounting_account_id,
      :expense_account_id,
      :accumulated_depreciation_account_id,
      :residual_value,
      :disposal_date,
      :disposal_reason,
      :disposal_value,
      :disposal_journal_entry_id,
      :notes,
      :attachments,
      :metadata,
      :month_value_change,
      :month_suspension_resumption,
      :month_writeoff_accounting,
      :month_writeoff_tax,
      :depreciation_months_current_year,
      :acquisition_cost_begin_year,
      :book_value_begin_year,
      :accumulated_depreciation_begin_year
    ])
    |> validate_required([
      :tenant_id,
      :code,
      :name,
      :category,
      :acquisition_date,
      :acquisition_cost,
      :useful_life_months,
      :depreciation_method,
      :status
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:depreciation_method, @depreciation_methods)
    |> validate_inclusion(:tax_category, Map.keys(@tax_categories),
      message: "трябва да е една от категориите I-VII според ЗКПО"
    )
    |> validate_number(:useful_life_months, greater_than: 0)
    |> validate_number(:acquisition_cost, greater_than: 0)
    |> validate_money(:acquisition_cost)
    |> validate_money(:salvage_value)
    |> validate_money(:residual_value)
    |> validate_money(:disposal_value)
    |> validate_depreciation_rates()
    |> set_default_tax_rate()
    |> unique_constraint(:code, name: :assets_tenant_id_code_index)
    |> unique_constraint(:inventory_number, name: :assets_tenant_id_inventory_number_index)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:accounting_account_id)
    |> foreign_key_constraint(:expense_account_id)
    |> foreign_key_constraint(:accumulated_depreciation_account_id)
    |> foreign_key_constraint(:supplier_id)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        is_nil(value) -> []
        Decimal.compare(value, Decimal.new(0)) in [:gt, :eq] -> []
        true -> [{field, "не може да е отрицателна"}]
      end
    end)
  end

  defp validate_depreciation_rates(changeset) do
    changeset
    |> validate_change(:tax_depreciation_rate, fn :tax_depreciation_rate, value ->
      cond do
        is_nil(value) ->
          []

        Decimal.compare(value, Decimal.new(0)) == :lt ->
          [tax_depreciation_rate: "не може да е отрицателна"]

        Decimal.compare(value, Decimal.new(1)) == :gt ->
          [tax_depreciation_rate: "не може да е над 100%"]

        true ->
          []
      end
    end)
    |> validate_change(:accounting_depreciation_rate, fn :accounting_depreciation_rate, value ->
      cond do
        is_nil(value) ->
          []

        Decimal.compare(value, Decimal.new(0)) == :lt ->
          [accounting_depreciation_rate: "не може да е отрицателна"]

        Decimal.compare(value, Decimal.new(1)) == :gt ->
          [accounting_depreciation_rate: "не може да е над 100%"]

        true ->
          []
      end
    end)
  end

  defp set_default_tax_rate(changeset) do
    case get_change(changeset, :tax_category) do
      nil ->
        changeset

      category ->
        case @tax_categories[category] do
          %{rate: nil} ->
            changeset

          %{rate: rate} ->
            # Set tax rate if not already set
            if get_field(changeset, :tax_depreciation_rate) == nil do
              put_change(changeset, :tax_depreciation_rate, Decimal.from_float(rate))
            else
              changeset
            end
        end
    end
  end

  @doc """
  Изчислява годишната амортизация по линеен метод
  """
  def calculate_annual_depreciation(%__MODULE__{} = asset, type \\ :accounting) do
    rate =
      case type do
        :accounting -> asset.accounting_depreciation_rate
        :tax -> asset.tax_depreciation_rate
      end

    if rate do
      Decimal.mult(asset.acquisition_cost, rate)
    else
      # Fallback to straight-line based on useful life
      depreciable_amount =
        Decimal.sub(asset.acquisition_cost, asset.salvage_value || Decimal.new(0))

      years = Decimal.div(Decimal.new(asset.useful_life_months), Decimal.new(12))
      Decimal.div(depreciable_amount, years)
    end
  end

  @doc """
  Изчислява месечната амортизация
  """
  def calculate_monthly_depreciation(%__MODULE__{} = asset, type \\ :accounting) do
    annual = calculate_annual_depreciation(asset, type)
    Decimal.div(annual, Decimal.new(12))
  end

  @doc """
  Проверява дали активът е напълно амортизиран
  """
  def fully_depreciated?(%__MODULE__{} = asset) do
    asset.status == "fully_depreciated" or
      (asset.residual_value &&
         Decimal.compare(asset.residual_value, asset.salvage_value || Decimal.new(0)) in [
           :eq,
           :lt
         ])
  end

  @doc """
  Проверява дали активът е изведен от употреба
  """
  def disposed?(%__MODULE__{} = asset) do
    asset.status == "disposed" and not is_nil(asset.disposal_date)
  end
end
