defmodule CyberCore.Manufacturing.ProductionOrderOperation do
  @moduledoc """
  Операция в производствена поръчка - изпълнение на стъпка от технологичната карта.

  Проследява:
  - Планирани vs реални времена
  - Статус на изпълнение
  - Оператор
  - Разходи за труд и машини
  - Резултати от качествен контрол
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Manufacturing.{ProductionOrder, TechCardOperation, WorkCenter}
  alias CyberCore.Accounts.User

  @statuses ~w(pending in_progress completed skipped)

  schema "production_order_operations" do
    field :tenant_id, :integer
    belongs_to :production_order, ProductionOrder
    belongs_to :tech_card_operation, TechCardOperation
    belongs_to :work_center, WorkCenter
    belongs_to :operator, User

    field :sequence_no, :integer
    field :name, :string
    field :description, :string

    # Статус
    field :status, :string, default: "pending"

    # Планирани времена (минути)
    field :planned_setup_time, :decimal, default: Decimal.new(0)
    field :planned_run_time, :decimal, default: Decimal.new(0)

    # Реални времена (минути)
    field :actual_setup_time, :decimal
    field :actual_run_time, :decimal

    # Дати на изпълнение
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    # Ставки
    field :labor_rate_per_hour, :decimal, default: Decimal.new(0)
    field :machine_rate_per_hour, :decimal, default: Decimal.new(0)

    # Разходи
    field :labor_cost, :decimal, default: Decimal.new(0)
    field :machine_cost, :decimal, default: Decimal.new(0)

    # Качествен контрол
    field :qc_passed, :boolean
    field :qc_notes, :string

    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [
      :tenant_id,
      :production_order_id,
      :tech_card_operation_id,
      :work_center_id,
      :operator_id,
      :sequence_no,
      :name,
      :description,
      :status,
      :planned_setup_time,
      :planned_run_time,
      :actual_setup_time,
      :actual_run_time,
      :started_at,
      :completed_at,
      :labor_rate_per_hour,
      :machine_rate_per_hour,
      :labor_cost,
      :machine_cost,
      :qc_passed,
      :qc_notes,
      :notes
    ])
    |> validate_required([:tenant_id, :production_order_id, :sequence_no, :name])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:sequence_no, greater_than: 0)
    |> validate_number(:planned_setup_time, greater_than_or_equal_to: 0)
    |> validate_number(:planned_run_time, greater_than_or_equal_to: 0)
    |> unique_constraint([:production_order_id, :sequence_no],
        name: :production_order_operations_production_order_id_sequence_no_index)
    |> foreign_key_constraint(:production_order_id)
    |> foreign_key_constraint(:tech_card_operation_id)
    |> foreign_key_constraint(:work_center_id)
    |> foreign_key_constraint(:operator_id)
  end

  @doc """
  Стартира операцията.
  """
  def start_changeset(operation, operator_id \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    operation
    |> change(%{
      status: "in_progress",
      started_at: now,
      operator_id: operator_id
    })
  end

  @doc """
  Завършва операцията.
  """
  def complete_changeset(operation, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    operation
    |> cast(attrs, [:actual_setup_time, :actual_run_time, :qc_passed, :qc_notes, :notes])
    |> change(%{
      status: "completed",
      completed_at: now
    })
    |> calculate_costs()
  end

  defp calculate_costs(changeset) do
    setup = get_field(changeset, :actual_setup_time) || get_field(changeset, :planned_setup_time) || Decimal.new(0)
    run = get_field(changeset, :actual_run_time) || get_field(changeset, :planned_run_time) || Decimal.new(0)

    total_minutes = Decimal.add(setup, run)
    total_hours = Decimal.div(total_minutes, Decimal.new(60))

    labor_rate = get_field(changeset, :labor_rate_per_hour) || Decimal.new(0)
    machine_rate = get_field(changeset, :machine_rate_per_hour) || Decimal.new(0)

    labor = Decimal.mult(total_hours, labor_rate)
    machine = Decimal.mult(total_hours, machine_rate)

    changeset
    |> put_change(:labor_cost, labor)
    |> put_change(:machine_cost, machine)
  end

  @doc """
  Пропуска операцията.
  """
  def skip_changeset(operation, reason \\ nil) do
    operation
    |> change(%{
      status: "skipped",
      notes: reason
    })
  end

  @doc """
  Изчислява общото време на операцията.
  """
  def total_time(%__MODULE__{actual_setup_time: setup, actual_run_time: run})
      when not is_nil(setup) and not is_nil(run) do
    Decimal.add(setup, run)
  end

  def total_time(%__MODULE__{planned_setup_time: setup, planned_run_time: run}) do
    Decimal.add(setup, run)
  end

  @doc """
  Проверява дали операцията е завършена.
  """
  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(_), do: false

  @doc """
  Списък със статуси.
  """
  def statuses, do: @statuses

  def status_label("pending"), do: "Чакаща"
  def status_label("in_progress"), do: "В изпълнение"
  def status_label("completed"), do: "Завършена"
  def status_label("skipped"), do: "Пропусната"
  def status_label(_), do: "Неизвестен"
end
