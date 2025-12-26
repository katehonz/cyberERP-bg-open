defmodule CyberCore.Manufacturing.ProductionOrder do
  @moduledoc """
  Производствена поръчка - изпълнение на производствен процес.

  Съдържа:
  - Връзка към технологична карта
  - Операции за изпълнение
  - Материали за производство
  - Проследяване на разходи (планирани vs реални)
  - Статус и дати
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.{Product, Warehouse}
  alias CyberCore.Manufacturing.{
    Recipe, TechCard,
    ProductionOrderItem, ProductionOrderOperation, ProductionOrderMaterial
  }

  @statuses ~w(draft planned in_progress completed canceled on_hold)

  schema "production_orders" do
    field :tenant_id, :integer

    # Връзка към технологична карта (нова) или рецепта (за съвместимост)
    belongs_to :tech_card, TechCard
    belongs_to :recipe, Recipe

    belongs_to :output_product, Product
    belongs_to :warehouse, Warehouse

    field :order_number, :string
    field :description, :string
    field :batch_number, :string

    # Количества
    field :quantity_to_produce, :decimal
    field :quantity_produced, :decimal, default: Decimal.new(0)
    field :unit, :string

    # Приоритет (1-10, 1 е най-висок)
    field :priority, :integer, default: 5

    # Статус
    field :status, :string, default: "draft"

    # Дати
    field :planned_date, :date
    field :start_date, :date
    field :completion_date, :date

    # Планирани разходи
    field :estimated_material_cost, :decimal, default: Decimal.new(0)
    field :estimated_labor_cost, :decimal, default: Decimal.new(0)
    field :estimated_machine_cost, :decimal, default: Decimal.new(0)
    field :estimated_total_cost, :decimal, default: Decimal.new(0)

    # Реални разходи
    field :actual_material_cost, :decimal, default: Decimal.new(0)
    field :actual_labor_cost, :decimal, default: Decimal.new(0)
    field :actual_machine_cost, :decimal, default: Decimal.new(0)
    field :actual_total_cost, :decimal, default: Decimal.new(0)

    field :notes, :string

    # Релации
    has_many :production_order_items, ProductionOrderItem
    has_many :operations, ProductionOrderOperation
    has_many :materials, ProductionOrderMaterial

    timestamps()
  end

  @doc false
  def changeset(production_order, attrs) do
    production_order
    |> cast(attrs, [
      :tenant_id,
      :tech_card_id,
      :recipe_id,
      :output_product_id,
      :warehouse_id,
      :order_number,
      :description,
      :batch_number,
      :quantity_to_produce,
      :quantity_produced,
      :unit,
      :priority,
      :status,
      :planned_date,
      :start_date,
      :completion_date,
      :estimated_material_cost,
      :estimated_labor_cost,
      :estimated_machine_cost,
      :estimated_total_cost,
      :actual_material_cost,
      :actual_labor_cost,
      :actual_machine_cost,
      :actual_total_cost,
      :notes
    ])
    |> validate_required([:tenant_id, :order_number, :quantity_to_produce, :output_product_id, :warehouse_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quantity_to_produce, greater_than: 0)
    |> validate_number(:priority, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_length(:order_number, max: 50)
    |> validate_length(:batch_number, max: 50)
    |> unique_constraint(:order_number, name: :production_orders_tenant_id_order_number_index)
    |> foreign_key_constraint(:tech_card_id)
    |> foreign_key_constraint(:recipe_id)
    |> foreign_key_constraint(:output_product_id)
    |> foreign_key_constraint(:warehouse_id)
  end

  @doc """
  Changeset за стартиране на производство.
  """
  def start_changeset(order) do
    order
    |> change(%{
      status: "in_progress",
      start_date: Date.utc_today()
    })
  end

  @doc """
  Changeset за завършване на производство.
  """
  def complete_changeset(order, quantity_produced) do
    order
    |> change(%{
      status: "completed",
      quantity_produced: quantity_produced,
      completion_date: Date.utc_today()
    })
  end

  @doc """
  Changeset за отмяна на производство.
  """
  def cancel_changeset(order, reason \\ nil) do
    order
    |> change(%{
      status: "canceled",
      notes: if(reason, do: "#{order.notes || ""}\nОтменено: #{reason}", else: order.notes)
    })
  end

  @doc """
  Changeset за задържане на производство.
  """
  def hold_changeset(order, reason \\ nil) do
    order
    |> change(%{
      status: "on_hold",
      notes: if(reason, do: "#{order.notes || ""}\nЗадържано: #{reason}", else: order.notes)
    })
  end

  @doc """
  Изчислява общите планирани разходи.
  """
  def calculate_estimated_costs(order) do
    total = Decimal.add(order.estimated_material_cost, order.estimated_labor_cost)
    |> Decimal.add(order.estimated_machine_cost)

    %{order | estimated_total_cost: total}
  end

  @doc """
  Изчислява общите реални разходи.
  """
  def calculate_actual_costs(order) do
    total = Decimal.add(order.actual_material_cost, order.actual_labor_cost)
    |> Decimal.add(order.actual_machine_cost)

    %{order | actual_total_cost: total}
  end

  @doc """
  Изчислява отклонението от плана (variance).
  """
  def cost_variance(%__MODULE__{estimated_total_cost: est, actual_total_cost: act}) do
    Decimal.sub(act, est)
  end

  @doc """
  Процент на изпълнение.
  """
  def completion_percent(%__MODULE__{quantity_to_produce: target, quantity_produced: produced}) do
    if Decimal.gt?(target, Decimal.new(0)) do
      Decimal.div(produced, target) |> Decimal.mult(Decimal.new(100)) |> Decimal.round(2)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Списък със статуси.
  """
  def statuses, do: @statuses

  def status_label("draft"), do: "Чернова"
  def status_label("planned"), do: "Планирана"
  def status_label("in_progress"), do: "В изпълнение"
  def status_label("completed"), do: "Завършена"
  def status_label("canceled"), do: "Отменена"
  def status_label("on_hold"), do: "Задържана"
  def status_label(_), do: "Неизвестен"

  @doc """
  Цвят за статус (за UI).
  """
  def status_color("draft"), do: "gray"
  def status_color("planned"), do: "blue"
  def status_color("in_progress"), do: "yellow"
  def status_color("completed"), do: "green"
  def status_color("canceled"), do: "red"
  def status_color("on_hold"), do: "orange"
  def status_color(_), do: "gray"
end
