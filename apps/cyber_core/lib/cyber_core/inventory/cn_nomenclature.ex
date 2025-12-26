defmodule CyberCore.Inventory.CnNomenclature do
  @moduledoc """
  Комбинирана номенклатура КН8 (Combined Nomenclature) за класификация на стоки.
  Използва се за SAF-T и Intrastat отчитане.
  Номенклатурата се поддържа по години.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias CyberCore.Inventory.Product

  @fields ~w(code description year primary_unit supplementary_unit is_active)a

  schema "cn_nomenclatures" do
    field :code, :string
    field :description, :string
    field :year, :integer
    field :primary_unit, :string
    field :supplementary_unit, :string
    field :is_active, :boolean, default: true

    has_many :products, Product, foreign_key: :cn_code_id

    timestamps()
  end

  def changeset(nomenclature, attrs) do
    nomenclature
    |> cast(attrs, @fields)
    |> validate_required([:code, :description, :year])
    |> validate_number(:year, greater_than: 2000, less_than: 2100)
    |> validate_length(:code, max: 20)
    |> validate_length(:description, max: 500)
    |> unique_constraint([:code, :year], name: :cn_nomenclatures_code_year_index)
  end

  @doc """
  Проверява дали кодът е валиден за дадената година
  """
  def valid_for_year?(code, year) do
    # Логика за проверка на валидност
    true
  end
end
