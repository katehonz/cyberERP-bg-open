defmodule CyberCore.Manufacturing.WorkCenter do
  @moduledoc """
  Работен център - машина, работна станция или производствена линия.
  Използва се за разпределение на операции и калкулация на машинни разходи.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @center_types ~w(machine workstation assembly_line manual outsourced)

  schema "work_centers" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :description, :string

    # Тип на центъра
    field :center_type, :string, default: "workstation"

    # Капацитет и разходи
    field :hourly_rate, :decimal, default: Decimal.new(0)
    field :capacity_per_hour, :decimal, default: Decimal.new(1)
    field :efficiency_percent, :decimal, default: Decimal.new(100)

    # Статус
    field :is_active, :boolean, default: true
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(work_center, attrs) do
    work_center
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :description,
      :center_type,
      :hourly_rate,
      :capacity_per_hour,
      :efficiency_percent,
      :is_active,
      :notes
    ])
    |> validate_required([:tenant_id, :code, :name])
    |> validate_inclusion(:center_type, @center_types)
    |> validate_number(:hourly_rate, greater_than_or_equal_to: 0)
    |> validate_number(:capacity_per_hour, greater_than: 0)
    |> validate_number(:efficiency_percent, greater_than: 0, less_than_or_equal_to: 200)
    |> validate_length(:code, max: 30)
    |> validate_length(:name, max: 120)
    |> unique_constraint(:code, name: :work_centers_tenant_id_code_index)
    |> foreign_key_constraint(:tenant_id)
  end

  @doc """
  Изчислява ефективната часова ставка с отчитане на ефективността.
  """
  def effective_hourly_rate(%__MODULE__{hourly_rate: rate, efficiency_percent: eff}) do
    Decimal.div(Decimal.mult(rate, Decimal.new(100)), eff)
  end

  @doc """
  Типове работни центрове.
  """
  def center_types, do: @center_types

  def center_type_label("machine"), do: "Машина"
  def center_type_label("workstation"), do: "Работна станция"
  def center_type_label("assembly_line"), do: "Монтажна линия"
  def center_type_label("manual"), do: "Ръчен труд"
  def center_type_label("outsourced"), do: "Външен изпълнител"
  def center_type_label(_), do: "Неизвестен"
end
