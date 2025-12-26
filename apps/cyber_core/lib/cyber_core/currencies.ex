defmodule CyberCore.Currencies do
  import Ecto.Query, warn: false
  alias CyberCore.Repo
  alias CyberCore.Currencies.Currency

  def list_currencies do
    Repo.all(from(c in Currency, order_by: [asc: c.code]))
  end

  def list_currencies(opts) when is_map(opts) do
    query = from(c in Currency, order_by: [asc: c.code])

    query =
      if Map.get(opts, :is_active) do
        from(c in query, where: c.is_active == true)
      else
        query
      end

    Repo.all(query)
  end

  def get_currency!(id), do: Repo.get!(Currency, id)

  def get_base_currency! do
    Repo.one!(from(c in Currency, where: c.is_base_currency == true))
  end

  def get_base_currency do
    Repo.one(from(c in Currency, where: c.is_base_currency == true))
  end

  def update_bnb_rates_today do
    CyberCore.Currencies.BnbService.update_current_rates()
  end

  def update_ecb_rates_today do
    CyberCore.Currencies.EcbService.update_current_rates()
  end

  def update_all_rates_today do
    {:ok, bnb_count} = update_bnb_rates_today()
    {:ok, ecb_count} = update_ecb_rates_today()
    total = bnb_count + ecb_count
    {:ok, %{bnb: bnb_count, ecb: ecb_count, total: total}}
  end
end
