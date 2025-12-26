defmodule CyberCore.Inventory.StockCount do
  @moduledoc """
  Инвентаризация - физическа проверка на складови наличности.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft in_progress completed cancelled)

  schema "stock_counts" do
    field :tenant_id, :integer
    field :count_number, :string
    field :count_date, :date
    field :status, :string, default: "draft"
    field :notes, :string
    field :completed_at, :naive_datetime
    field :count_type, :string, default: "full"

    # Връзки
    belongs_to :warehouse, CyberCore.Inventory.Warehouse
    field :created_by_id, :integer
    field :completed_by_id, :integer
    has_many :count_lines, CyberCore.Inventory.StockCountLine

    timestamps()
  end

  @doc false
  def changeset(stock_count, attrs) do
    stock_count
    |> cast(attrs, [
      :tenant_id,
      :warehouse_id,
      :count_number,
      :count_date,
      :status,
      :notes,
      :count_type,
      :completed_at,
      :created_by_id,
      :completed_by_id
    ])
    |> validate_required([:tenant_id, :warehouse_id, :count_date])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:count_type, ~w(full partial cycle))
    |> generate_count_number()
  end

  defp generate_count_number(changeset) do
    case get_field(changeset, :count_number) do
      nil ->
        date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")
        number = "INV-#{date_str}-#{:rand.uniform(9999)}"
        put_change(changeset, :count_number, number)

      _ ->
        changeset
    end
  end
end
