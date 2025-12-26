defmodule CyberCore.Repo.Migrations.CreateTechCardsSystem do
  use Ecto.Migration

  def change do
    # =====================================================
    # Работни центрове (машини, станции, линии)
    # =====================================================
    create table(:work_centers) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :code, :string, size: 30, null: false
      add :name, :string, size: 120, null: false
      add :description, :text

      # Тип: machine, workstation, assembly_line, manual
      add :center_type, :string, size: 30, default: "workstation"

      # Капацитет и разходи
      add :hourly_rate, :decimal, precision: 15, scale: 4, default: 0
      add :capacity_per_hour, :decimal, precision: 15, scale: 4, default: 1
      add :efficiency_percent, :decimal, precision: 5, scale: 2, default: 100

      # Статус
      add :is_active, :boolean, default: true
      add :notes, :text

      timestamps()
    end

    create unique_index(:work_centers, [:tenant_id, :code])
    create index(:work_centers, [:tenant_id])
    create index(:work_centers, [:center_type])

    # =====================================================
    # Технологични карти (заменят рецептите)
    # =====================================================
    create table(:tech_cards) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :code, :string, size: 30, null: false
      add :name, :string, size: 120, null: false
      add :description, :text

      # Изходен продукт
      add :output_product_id, references(:products, on_delete: :nilify_all)
      add :output_quantity, :decimal, precision: 15, scale: 4, default: 1
      add :output_unit, :string, size: 20, default: "бр."

      # Версия и валидност
      add :version, :string, size: 20, default: "1.0"
      add :valid_from, :date
      add :valid_to, :date
      add :is_active, :boolean, default: true

      # Разходи (автоматично изчисляеми)
      add :material_cost, :decimal, precision: 15, scale: 4, default: 0
      add :labor_cost, :decimal, precision: 15, scale: 4, default: 0
      add :machine_cost, :decimal, precision: 15, scale: 4, default: 0
      add :overhead_cost, :decimal, precision: 15, scale: 4, default: 0
      add :total_cost, :decimal, precision: 15, scale: 4, default: 0

      # Overhead коефициент (% от преки разходи)
      add :overhead_percent, :decimal, precision: 5, scale: 2, default: 0

      add :notes, :text

      timestamps()
    end

    create unique_index(:tech_cards, [:tenant_id, :code])
    create index(:tech_cards, [:tenant_id])
    create index(:tech_cards, [:output_product_id])
    create index(:tech_cards, [:is_active])

    # =====================================================
    # Материали в технологична карта (BOM с коефициенти и формули)
    # =====================================================
    create table(:tech_card_materials) do
      add :tenant_id, :integer, null: false
      add :tech_card_id, references(:tech_cards, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict), null: false

      add :line_no, :integer, default: 10
      add :description, :string, size: 255

      # Количество и мерна единица
      add :quantity, :decimal, precision: 15, scale: 6, null: false
      add :unit, :string, size: 20, default: "бр."

      # Коефициенти за изчисления
      add :coefficient, :decimal, precision: 10, scale: 6, default: 1.0
      add :wastage_percent, :decimal, precision: 5, scale: 2, default: 0

      # Формула за количество (Elixir expression)
      # Примери: "quantity * 1.05", "quantity * coefficient + 0.5"
      # Ако е nil, използва се: quantity * coefficient * (1 + wastage_percent/100)
      add :quantity_formula, :string, size: 255

      # Цена и разход
      add :unit_cost, :decimal, precision: 15, scale: 4, default: 0
      add :total_cost, :decimal, precision: 15, scale: 4, default: 0

      # Опционално: фиксиран материал или пропорционален
      add :is_fixed, :boolean, default: false

      add :notes, :text

      timestamps()
    end

    create index(:tech_card_materials, [:tech_card_id])
    create index(:tech_card_materials, [:product_id])
    create unique_index(:tech_card_materials, [:tech_card_id, :line_no])

    # =====================================================
    # Операции в технологична карта (работни стъпки)
    # =====================================================
    create table(:tech_card_operations) do
      add :tenant_id, :integer, null: false
      add :tech_card_id, references(:tech_cards, on_delete: :delete_all), null: false
      add :work_center_id, references(:work_centers, on_delete: :nilify_all)

      add :sequence_no, :integer, null: false
      add :operation_code, :string, size: 30
      add :name, :string, size: 120, null: false
      add :description, :text

      # Времена (в минути)
      add :setup_time, :decimal, precision: 10, scale: 2, default: 0
      add :run_time_per_unit, :decimal, precision: 10, scale: 4, default: 0
      add :wait_time, :decimal, precision: 10, scale: 2, default: 0
      add :move_time, :decimal, precision: 10, scale: 2, default: 0

      # Коефициенти за изчисления
      add :time_coefficient, :decimal, precision: 10, scale: 6, default: 1.0
      add :efficiency_coefficient, :decimal, precision: 10, scale: 6, default: 1.0

      # Формула за време (Elixir expression)
      # Примери: "setup_time + run_time_per_unit * quantity"
      # Ако е nil, използва се стандартната формула
      add :time_formula, :string, size: 255

      # Разходи
      add :labor_rate_per_hour, :decimal, precision: 15, scale: 4, default: 0
      add :machine_rate_per_hour, :decimal, precision: 15, scale: 4, default: 0
      add :labor_cost, :decimal, precision: 15, scale: 4, default: 0
      add :machine_cost, :decimal, precision: 15, scale: 4, default: 0
      add :total_cost, :decimal, precision: 15, scale: 4, default: 0

      # Контрол на качеството
      add :requires_qc, :boolean, default: false
      add :qc_instructions, :text

      # Инструменти и настройки
      add :tools_required, :text
      add :setup_instructions, :text

      add :notes, :text

      timestamps()
    end

    create index(:tech_card_operations, [:tech_card_id])
    create index(:tech_card_operations, [:work_center_id])
    create unique_index(:tech_card_operations, [:tech_card_id, :sequence_no])

    # =====================================================
    # Актуализация на production_orders - добавяме tech_card_id
    # =====================================================
    alter table(:production_orders) do
      add :tech_card_id, references(:tech_cards, on_delete: :nilify_all)

      # Допълнителни полета за проследяване
      add :priority, :integer, default: 5  # 1-10, 1 е най-висок приоритет
      add :batch_number, :string, size: 50

      # Изчислени разходи
      add :estimated_material_cost, :decimal, precision: 15, scale: 4, default: 0
      add :estimated_labor_cost, :decimal, precision: 15, scale: 4, default: 0
      add :estimated_machine_cost, :decimal, precision: 15, scale: 4, default: 0
      add :estimated_total_cost, :decimal, precision: 15, scale: 4, default: 0

      add :actual_material_cost, :decimal, precision: 15, scale: 4, default: 0
      add :actual_labor_cost, :decimal, precision: 15, scale: 4, default: 0
      add :actual_machine_cost, :decimal, precision: 15, scale: 4, default: 0
      add :actual_total_cost, :decimal, precision: 15, scale: 4, default: 0
    end

    create index(:production_orders, [:tech_card_id])
    create index(:production_orders, [:priority])
    create index(:production_orders, [:batch_number])

    # =====================================================
    # Операции в производствена поръчка (изпълнение)
    # =====================================================
    create table(:production_order_operations) do
      add :tenant_id, :integer, null: false
      add :production_order_id, references(:production_orders, on_delete: :delete_all), null: false
      add :tech_card_operation_id, references(:tech_card_operations, on_delete: :nilify_all)
      add :work_center_id, references(:work_centers, on_delete: :nilify_all)

      add :sequence_no, :integer, null: false
      add :name, :string, size: 120, null: false
      add :description, :text

      # Статус: pending, in_progress, completed, skipped
      add :status, :string, size: 20, default: "pending"

      # Планирани времена
      add :planned_setup_time, :decimal, precision: 10, scale: 2, default: 0
      add :planned_run_time, :decimal, precision: 10, scale: 2, default: 0

      # Реални времена
      add :actual_setup_time, :decimal, precision: 10, scale: 2
      add :actual_run_time, :decimal, precision: 10, scale: 2

      # Дати
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      # Оператор
      add :operator_id, references(:users, on_delete: :nilify_all)

      # Разходи
      add :labor_cost, :decimal, precision: 15, scale: 4, default: 0
      add :machine_cost, :decimal, precision: 15, scale: 4, default: 0

      # Качествен контрол
      add :qc_passed, :boolean
      add :qc_notes, :text

      add :notes, :text

      timestamps()
    end

    create index(:production_order_operations, [:production_order_id])
    create index(:production_order_operations, [:status])
    create unique_index(:production_order_operations, [:production_order_id, :sequence_no])

    # =====================================================
    # Материали изразходвани в производствена поръчка
    # =====================================================
    create table(:production_order_materials) do
      add :tenant_id, :integer, null: false
      add :production_order_id, references(:production_orders, on_delete: :delete_all), null: false
      add :tech_card_material_id, references(:tech_card_materials, on_delete: :nilify_all)
      add :product_id, references(:products, on_delete: :restrict), null: false

      add :line_no, :integer, default: 10
      add :description, :string, size: 255

      # Планирано количество
      add :planned_quantity, :decimal, precision: 15, scale: 6, null: false
      add :unit, :string, size: 20, default: "бр."

      # Реално изразходвано
      add :actual_quantity, :decimal, precision: 15, scale: 6

      # Цена
      add :unit_cost, :decimal, precision: 15, scale: 4, default: 0
      add :total_cost, :decimal, precision: 15, scale: 4, default: 0

      # Статус: pending, issued, returned
      add :status, :string, size: 20, default: "pending"

      add :notes, :text

      timestamps()
    end

    create index(:production_order_materials, [:production_order_id])
    create index(:production_order_materials, [:product_id])
    create index(:production_order_materials, [:status])
  end
end
