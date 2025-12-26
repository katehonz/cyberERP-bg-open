defmodule CyberCore.SAFT.Nomenclature.Country do
  @moduledoc """
  Държави според ISO 3166-1.

  Съдържа:
  - Двубуквени кодове (напр. BG, DE, US)
  - Трибуквени кодове (напр. BGR, DEU, USA)
  - Цифрови кодове
  - Наименования на български и английски
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "saft_countries" do
    field :code, :string
    field :code3, :string
    field :numeric_code, :string
    field :name_bg, :string
    field :name_en, :string
    field :name_official, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(country, attrs) do
    country
    |> cast(attrs, [:code, :code3, :numeric_code, :name_bg, :name_en, :name_official])
    |> validate_required([:code, :name_bg, :name_en])
    |> validate_length(:code, is: 2)
    |> validate_length(:code3, is: 3)
    |> validate_length(:numeric_code, is: 3)
    |> unique_constraint(:code)
    |> unique_constraint(:code3)
  end

  @doc """
  Проверява дали кодът на държавата е валиден.
  """
  def valid_code?(code) when is_binary(code) do
    case CyberCore.Repo.get_by(__MODULE__, code: String.upcase(code)) do
      nil -> false
      _ -> true
    end
  end

  def valid_code?(_), do: false
end
