defmodule CyberCore.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :base_currency_code, :string, default: "BGN"
    field :base_currency_changed_at, :utc_datetime
    field :in_eurozone, :boolean, default: false
    field :eurozone_entry_date, :date

    timestamps()
  end

  @doc """
  Changeset за създаване на нов tenant.
  """
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :base_currency_code])
    |> validate_required([:name, :slug, :base_currency_code])
    |> update_change(:slug, &String.trim/1)
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/)
    |> unique_constraint(:slug)
    |> validate_inclusion(:base_currency_code, ["BGN", "EUR", "USD", "GBP"])
  end

  @doc """
  Changeset за промяна на основната валута.
  Валидира дали е позволена промяната според датата и еврозоната.
  """
  def change_base_currency_changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:base_currency_code, :in_eurozone, :eurozone_entry_date])
    |> validate_required([:base_currency_code])
    |> validate_inclusion(:base_currency_code, ["BGN", "EUR", "USD", "GBP"])
    |> validate_currency_change_allowed()
    |> put_change(:base_currency_changed_at, DateTime.utc_now())
  end

  # Валидация дали е позволена промяна на валутата
  defp validate_currency_change_allowed(changeset) do
    base_currency_code = get_field(changeset, :base_currency_code)
    old_currency_code = get_field(changeset, :base_currency_code, :original)
    in_eurozone = get_field(changeset, :in_eurozone, false)
    eurozone_entry_date = get_field(changeset, :eurozone_entry_date)

    cond do
      # Ако няма промяна на валутата, всичко е ОК
      base_currency_code == old_currency_code ->
        changeset

      # Ако сме в еврозоната, валутата ТРЯБВА да е EUR
      in_eurozone and base_currency_code != "EUR" ->
        add_error(
          changeset,
          :base_currency_code,
          "В еврозоната основната валута трябва да е EUR"
        )

      # Ако имаме зададена дата на влизане в еврозоната и тя е преминала
      eurozone_entry_date && Date.compare(Date.utc_today(), eurozone_entry_date) != :lt ->
        add_error(
          changeset,
          :base_currency_code,
          "Не може да се променя основната валута след влизане в еврозоната (#{eurozone_entry_date})"
        )

      # В противен случай промяната е позволена
      true ->
        changeset
    end
  end
end
