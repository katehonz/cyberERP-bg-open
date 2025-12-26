defmodule CyberCore.SAFT.Nomenclature.IBANFormat do
  @moduledoc """
  IBAN формати по държави според ISO 13616-1997.

  Използва се за валидация на IBAN номера на банкови сметки.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "saft_iban_formats" do
    field :country, :string
    field :country_code, :string
    field :char_count, :integer
    field :bank_code_format, :string
    field :iban_fields, :string
    field :comments, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(iban_format, attrs) do
    iban_format
    |> cast(attrs, [
      :country,
      :country_code,
      :char_count,
      :bank_code_format,
      :iban_fields,
      :comments
    ])
    |> validate_required([:country, :country_code, :char_count])
    |> validate_length(:country_code, is: 2)
    |> validate_number(:char_count, greater_than: 0, less_than_or_equal_to: 34)
    |> unique_constraint(:country_code)
  end

  @doc """
  Връща броя символи за IBAN на дадена държава.
  """
  def get_char_count(country_code) when is_binary(country_code) do
    # This will be cached via ETS
    case CyberCore.Repo.get_by(__MODULE__, country_code: String.upcase(country_code)) do
      nil -> {:error, :unknown_country}
      format -> {:ok, format.char_count}
    end
  end
end
