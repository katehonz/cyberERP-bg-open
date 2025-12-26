defmodule CyberCore.Accounting.AssetTransaction do
  @moduledoc """
  Транзакции с дълготрайни активи за SAF-T отчитане.

  Записва всички движения на активи според изискванията на НАП:
  - Придобиване (ACQ - код 10)
  - Подобрение/Увеличаване на стойност (IMP - код 20)
  - Амортизация (DEP - код 30)
  - Преоценка (REV - код 40)
  - Продажба (DSP - код 50)
  - Брак/Отписване (SCR - код 60)
  - Вътрешен трансфер (TRF - код 70)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Accounting.{Asset, JournalEntry}
  alias CyberCore.Accounts.Tenant
  alias CyberCore.Contacts.Contact
  alias Decimal

  @transaction_types %{
    "10" => "ACQ - Придобиване",
    "20" => "IMP - Подобрение/Увеличаване",
    "30" => "DEP - Амортизация",
    "40" => "REV - Преоценка",
    "50" => "DSP - Продажба",
    "60" => "SCR - Брак/Отписване",
    "70" => "TRF - Вътрешен трансфер",
    "80" => "COR - Корекция"
  }

  schema "asset_transactions" do
    belongs_to :tenant, Tenant
    belongs_to :asset, Asset

    # Transaction details
    # Код: 10, 20, 30, 40, 50, 60, 70, 80
    field :transaction_type, :string
    field :transaction_date, :date
    field :description, :string

    # Values
    # Сума на транзакцията
    field :transaction_amount, :decimal
    # Промяна в придобивна стойност
    field :acquisition_cost_change, :decimal
    # Балансова стойност след транзакцията
    field :book_value_after, :decimal

    # Supplier/Customer for the transaction
    belongs_to :supplier_customer, Contact

    # Link to journal entry
    belongs_to :journal_entry, JournalEntry

    # Additional SAF-T fields
    # ID на транзакцията в SAF-T
    field :saft_transaction_id, :string
    # Година на транзакцията
    field :year, :integer
    # Месец на транзакцията
    field :month, :integer

    timestamps()
  end

  @doc """
  Връща списък с налични типове транзакции
  """
  def transaction_types, do: @transaction_types

  @doc """
  Проверява дали кодът на транзакцията е валиден
  """
  def valid_transaction_type?(type) when is_binary(type) do
    Map.has_key?(@transaction_types, type)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :tenant_id,
      :asset_id,
      :transaction_type,
      :transaction_date,
      :description,
      :transaction_amount,
      :acquisition_cost_change,
      :book_value_after,
      :supplier_customer_id,
      :journal_entry_id,
      :saft_transaction_id,
      :year,
      :month
    ])
    |> validate_required([
      :tenant_id,
      :asset_id,
      :transaction_type,
      :transaction_date,
      :transaction_amount
    ])
    |> validate_inclusion(:transaction_type, Map.keys(@transaction_types))
    |> validate_number(:transaction_amount, greater_than_or_equal_to: 0)
    |> validate_number(:year, greater_than: 2000, less_than: 2100)
    |> validate_number(:month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> set_year_month()
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:supplier_customer_id)
    |> foreign_key_constraint(:journal_entry_id)
  end

  defp set_year_month(changeset) do
    case get_change(changeset, :transaction_date) do
      nil ->
        changeset

      date ->
        changeset
        |> put_change(:year, date.year)
        |> put_change(:month, date.month)
    end
  end

  @doc """
  Връща името на транзакцията по код
  """
  def transaction_name(type) when is_binary(type) do
    Map.get(@transaction_types, type, "Неизвестен тип")
  end
end
