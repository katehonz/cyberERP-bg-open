defmodule CyberCore.Manufacturing.TechCardOperation do
  @moduledoc """
  Операция в технологична карта - работна стъпка от производствения процес.

  Включва:
  - Работен център (машина/станция)
  - Времена (setup, run, wait, move)
  - Коефициенти за изчисление
  - Формула за време
  - Разходи за труд и машини
  - Контрол на качеството
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Manufacturing.{TechCard, WorkCenter}

  schema "tech_card_operations" do
    field :tenant_id, :integer
    belongs_to :tech_card, TechCard
    belongs_to :work_center, WorkCenter

    field :sequence_no, :integer
    field :operation_code, :string
    field :name, :string
    field :description, :string

    # Времена (в минути)
    field :setup_time, :decimal, default: Decimal.new(0)
    field :run_time_per_unit, :decimal, default: Decimal.new(0)
    field :wait_time, :decimal, default: Decimal.new(0)
    field :move_time, :decimal, default: Decimal.new(0)

    # Коефициенти
    field :time_coefficient, :decimal, default: Decimal.new("1.0")
    field :efficiency_coefficient, :decimal, default: Decimal.new("1.0")

    # Формула за време (опционална)
    # Променливи: setup_time, run_time_per_unit, wait_time, move_time,
    #             time_coefficient, efficiency_coefficient, quantity
    field :time_formula, :string

    # Разходи (на час)
    field :labor_rate_per_hour, :decimal, default: Decimal.new(0)
    field :machine_rate_per_hour, :decimal, default: Decimal.new(0)

    # Изчислени разходи
    field :labor_cost, :decimal, default: Decimal.new(0)
    field :machine_cost, :decimal, default: Decimal.new(0)
    field :total_cost, :decimal, default: Decimal.new(0)

    # Контрол на качеството
    field :requires_qc, :boolean, default: false
    field :qc_instructions, :string

    # Инструменти и настройки
    field :tools_required, :string
    field :setup_instructions, :string

    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [
      :tenant_id,
      :tech_card_id,
      :work_center_id,
      :sequence_no,
      :operation_code,
      :name,
      :description,
      :setup_time,
      :run_time_per_unit,
      :wait_time,
      :move_time,
      :time_coefficient,
      :efficiency_coefficient,
      :time_formula,
      :labor_rate_per_hour,
      :machine_rate_per_hour,
      :labor_cost,
      :machine_cost,
      :total_cost,
      :requires_qc,
      :qc_instructions,
      :tools_required,
      :setup_instructions,
      :notes
    ])
    |> validate_required([:tenant_id, :tech_card_id, :sequence_no, :name])
    |> validate_number(:sequence_no, greater_than: 0)
    |> validate_number(:setup_time, greater_than_or_equal_to: 0)
    |> validate_number(:run_time_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:wait_time, greater_than_or_equal_to: 0)
    |> validate_number(:move_time, greater_than_or_equal_to: 0)
    |> validate_number(:time_coefficient, greater_than: 0)
    |> validate_number(:efficiency_coefficient, greater_than: 0)
    |> validate_formula(:time_formula)
    |> validate_length(:name, max: 120)
    |> validate_length(:operation_code, max: 30)
    |> unique_constraint([:tech_card_id, :sequence_no], name: :tech_card_operations_tech_card_id_sequence_no_index)
    |> foreign_key_constraint(:tech_card_id)
    |> foreign_key_constraint(:work_center_id)
  end

  defp validate_formula(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      "" -> changeset
      formula ->
        case CyberCore.Manufacturing.FormulaEngine.validate_formula(formula) do
          :ok -> changeset
          {:error, reason} -> add_error(changeset, field, reason)
        end
    end
  end

  @doc """
  Изчислява общото време за операцията (в минути).

  ## Параметри
    - operation: TechCardOperation struct
    - quantity: количество единици за производство

  ## Връща
    - Decimal: общо време в минути
  """
  def calculate_time(%__MODULE__{} = op, quantity) do
    context = %{
      setup_time: op.setup_time,
      run_time_per_unit: op.run_time_per_unit,
      wait_time: op.wait_time,
      move_time: op.move_time,
      time_coefficient: op.time_coefficient,
      efficiency_coefficient: op.efficiency_coefficient,
      quantity: quantity
    }

    case op.time_formula do
      nil -> default_time_formula(context)
      "" -> default_time_formula(context)
      formula -> evaluate_formula(formula, context)
    end
  end

  defp default_time_formula(ctx) do
    # Стандартна формула:
    # (setup_time + run_time_per_unit * quantity + wait_time + move_time) * time_coefficient / efficiency_coefficient
    run_total = Decimal.mult(ctx.run_time_per_unit, ctx.quantity)

    base_time = ctx.setup_time
    |> Decimal.add(run_total)
    |> Decimal.add(ctx.wait_time)
    |> Decimal.add(ctx.move_time)

    adjusted = Decimal.mult(base_time, ctx.time_coefficient)
    Decimal.div(adjusted, ctx.efficiency_coefficient)
  end

  defp evaluate_formula(formula, context) do
    CyberCore.Manufacturing.FormulaEngine.evaluate(formula, context)
  end

  @doc """
  Изчислява разходите за операцията.

  ## Параметри
    - operation: TechCardOperation struct
    - quantity: количество единици

  ## Връща
    - map с :labor_cost, :machine_cost, :total_cost
  """
  def calculate_costs(%__MODULE__{} = op, quantity) do
    time_minutes = calculate_time(op, quantity)
    time_hours = Decimal.div(time_minutes, Decimal.new(60))

    labor = Decimal.mult(time_hours, op.labor_rate_per_hour)
    machine = Decimal.mult(time_hours, op.machine_rate_per_hour)
    total = Decimal.add(labor, machine)

    %{
      labor_cost: labor,
      machine_cost: machine,
      total_cost: total,
      time_minutes: time_minutes,
      time_hours: time_hours
    }
  end

  @doc """
  Форматира времето в часове и минути.
  """
  def format_time(minutes) when is_struct(minutes, Decimal) do
    total_minutes = Decimal.to_float(minutes) |> round()
    hours = div(total_minutes, 60)
    mins = rem(total_minutes, 60)

    cond do
      hours > 0 and mins > 0 -> "#{hours}ч #{mins}мин"
      hours > 0 -> "#{hours}ч"
      true -> "#{mins}мин"
    end
  end
end
