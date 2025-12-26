defmodule CyberCore.Accounting.VatReturn do
  @moduledoc """
  ДДС декларация (VAT Return) според ЗДДС.

  Месечна или тримесечна декларация за начислен и приспадащ се ДДС.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Decimal, as: D

  @statuses ~w(draft submitted accepted)

  schema "vat_returns" do
    field :tenant_id, :integer

    # Период
    field :period_year, :integer
    field :period_month, :integer

    # Статус
    field :status, :string, default: "draft"

    # Начислен ДДС по продажби
    field :total_sales_taxable, :decimal
    field :total_sales_vat, :decimal

    # Приспадащ се ДДС по покупки
    field :total_purchases_taxable, :decimal
    field :total_purchases_vat, :decimal
    field :total_deductible_vat, :decimal

    # Резултат
    # За внасяне
    field :vat_payable, :decimal
    # За възстановяване
    field :vat_refundable, :decimal

    # Дати
    field :submission_date, :date
    field :due_date, :date

    # Забележки
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(vat_return, attrs) do
    vat_return
    |> cast(attrs, [
      :tenant_id,
      :period_year,
      :period_month,
      :status,
      :total_sales_taxable,
      :total_sales_vat,
      :total_purchases_taxable,
      :total_purchases_vat,
      :total_deductible_vat,
      :vat_payable,
      :vat_refundable,
      :submission_date,
      :due_date,
      :notes
    ])
    |> validate_required([
      :tenant_id,
      :period_year,
      :period_month
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:period_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> unique_constraint([:tenant_id, :period_year, :period_month])
    |> calculate_result()
  end

  defp calculate_result(changeset) do
    sales_vat = get_field(changeset, :total_sales_vat) || D.new(0)
    deductible_vat = get_field(changeset, :total_deductible_vat) || D.new(0)

    diff = D.sub(sales_vat, deductible_vat)

    changeset =
      if D.gt?(diff, 0) do
        changeset
        |> put_change(:vat_payable, diff)
        |> put_change(:vat_refundable, D.new(0))
      else
        changeset
        |> put_change(:vat_payable, D.new(0))
        |> put_change(:vat_refundable, D.abs(diff))
      end

    # Изчисли срока за подаване (14-ти ден на следващия месец)
    if get_field(changeset, :period_year) && get_field(changeset, :period_month) do
      year = get_field(changeset, :period_year)
      month = get_field(changeset, :period_month)

      {next_year, next_month} =
        if month == 12 do
          {year + 1, 1}
        else
          {year, month + 1}
        end

      due_date = Date.new!(next_year, next_month, 14)
      put_change(changeset, :due_date, due_date)
    else
      changeset
    end
  end
end
