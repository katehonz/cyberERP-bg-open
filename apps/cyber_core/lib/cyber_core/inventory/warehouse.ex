defmodule CyberCore.Inventory.Warehouse do
  @moduledoc """
  Складова схема за управление на складови помещения.

  ## Методи за оценка на материалните запаси

  - `weighted_average` - Средно претеглена цена (по подразбиране)
  - `fifo` - Първа входяща, първа изходяща (First In, First Out)
  - `lifo` - Последна входяща, първа изходяща (Last In, First Out)

  Забележка: Услугите не са материални запаси и не се оценяват.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @costing_methods ~w(weighted_average fifo lifo)

  @derive {Jason.Encoder, only: [:id, :code, :name, :address, :city, :postal_code, :country, :is_active, :costing_method, :notes]}

  schema "warehouses" do
    field :tenant_id, :integer
    field :code, :string
    field :name, :string
    field :address, :string
    field :city, :string
    field :postal_code, :string
    field :country, :string, default: "BG"
    field :is_active, :boolean, default: true
    field :notes, :string

    # Метод за оценка на материалните запаси
    field :costing_method, :string, default: "weighted_average"

    # Връзки
    has_many :stock_movements, CyberCore.Inventory.StockMovement

    timestamps()
  end

  @doc false
  def changeset(warehouse, attrs) do
    warehouse
    |> cast(attrs, [
      :tenant_id,
      :code,
      :name,
      :address,
      :city,
      :postal_code,
      :country,
      :is_active,
      :costing_method,
      :notes
    ])
    |> validate_required([:tenant_id, :code, :name])
    |> validate_length(:code, max: 20)
    |> validate_length(:name, max: 200)
    |> validate_inclusion(:costing_method, @costing_methods,
      message: "трябва да бъде: средно претеглена, FIFO или LIFO"
    )
    |> unique_constraint([:tenant_id, :code])
  end

  @doc """
  Връща списък с валидните методи за оценка.
  """
  def costing_methods, do: @costing_methods

  @doc """
  Връща човешко-четимо име на метода за оценка.
  """
  def costing_method_name("weighted_average"), do: "Средно претеглена цена"
  def costing_method_name("fifo"), do: "FIFO (Първа входяща, първа изходяща)"
  def costing_method_name("lifo"), do: "LIFO (Последна входяща, първа изходяща)"
  def costing_method_name(_), do: "Неизвестен"
end
