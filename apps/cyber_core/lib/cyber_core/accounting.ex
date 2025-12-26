defmodule CyberCore.Accounting do
  @moduledoc """
  Финансов и счетоводен модул.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo

  alias CyberCore.Accounting.{
    Account,
    Asset,
    AssetDepreciationSchedule,
    ChartOfAccountsXML,
    EntryLine,
    FinancialAccount,
    FinancialTransaction,
    JournalEntry,
    VatRate
  }

  alias Decimal, as: D

  # -- Accounts --

  def list_accounts(tenant_id) do
    Repo.all(from a in Account, where: a.tenant_id == ^tenant_id, order_by: [asc: a.code])
  end

  def get_account!(tenant_id, id) do
    Repo.get_by!(Account, tenant_id: tenant_id, id: id)
  end

  def create_account(tenant_id, attrs) do
    attrs = Map.put(attrs, :tenant_id, tenant_id)

    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_account/1)
  end

  def update_account(tenant_id, %Account{} = account, attrs) do
    attrs = Map.put(attrs, :tenant_id, tenant_id)

    account
    |> Account.changeset(attrs)
    |> Repo.update()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_account/1)
  end

  def delete_account(%Account{} = account) do
    result = Repo.delete(account)
    CyberCore.Cache.Invalidator.invalidate_accounts()
    result
  end

  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  # -- Chart of Accounts XML Import/Export --

  @doc """
  Експортира сметкоплан в XML формат.
  """
  def export_chart_of_accounts(tenant_id) do
    ChartOfAccountsXML.export(tenant_id)
  end

  @doc """
  Импортира сметкоплан от XML.

  Options:
    - :replace - изтрива съществуващите сметки преди импорт
    - :skip_existing - пропуска сметки, които вече съществуват
  """
  def import_chart_of_accounts(tenant_id, xml_content, opts \\ []) do
    ChartOfAccountsXML.import_accounts(tenant_id, xml_content, opts)
  end

  @doc """
  Валидира XML сметкоплан без импортиране.
  """
  def validate_chart_of_accounts_xml(xml_content) do
    ChartOfAccountsXML.validate(xml_content)
  end

  @doc """
  Взима сметка по код.
  """
  def get_account_by_code(code, tenant_id) do
    Repo.get_by(Account, code: code, tenant_id: tenant_id)
  end

  @doc """
  Взима сметка по ID без tenant_id (за cache).
  """
  def get_account(id) do
    Repo.get(Account, id)
  end

  @doc """
  Връща списък със сметки, които имат зададени начални салда.
  """
  def list_accountsWithOpeningBalances(tenant_id) do
    from(a in Account,
      where: a.tenant_id == ^tenant_id and fragment("abs(?)", a.opening_balance) > 0,
      order_by: [asc: a.code]
    )
    |> Repo.all()
  end

  # -- Journal entries --

  def list_journal_entries(tenant_id, opts \\ []) do
    base_query =
      from je in JournalEntry,
        where: je.tenant_id == ^tenant_id,
        order_by: [desc: je.document_date]

    Repo.all(apply_journal_filters(base_query, opts))
  end

  def get_journal_entry!(tenant_id, id, preloads \\ []) do
    JournalEntry
    |> where([je], je.tenant_id == ^tenant_id and je.id == ^id)
    |> Repo.one!()
    |> Repo.preload(preloads)
  end

  def create_journal_entry(attrs) do
    %JournalEntry{}
    |> JournalEntry.changeset(attrs)
    |> Repo.insert()
  end

  def create_journal_entry_with_lines(entry_attrs, lines_attrs) when is_list(lines_attrs) do
    Repo.transaction(fn ->
      with {:ok, entry} <- create_journal_entry(entry_attrs),
           {:ok, _lines} <- insert_entry_lines(entry, lines_attrs) do
        Repo.preload(entry, :lines)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_journal_entry(%JournalEntry{} = entry, attrs) do
    entry
    |> JournalEntry.changeset(attrs)
    |> Repo.update()
  end

  def delete_journal_entry(%JournalEntry{} = entry), do: Repo.delete(entry)

  # -- Entry lines --

  def list_entry_lines(entry_id) do
    Repo.all(
      from el in EntryLine,
        where: el.journal_entry_id == ^entry_id,
        order_by: [asc: el.line_order, asc: el.inserted_at]
    )
  end

  def create_entry_line(attrs) do
    %EntryLine{}
    |> EntryLine.changeset(attrs)
    |> Repo.insert()
  end

  def update_entry_line(%EntryLine{} = line, attrs) do
    line
    |> EntryLine.changeset(attrs)
    |> Repo.update()
  end

  def delete_entry_line(%EntryLine{} = line), do: Repo.delete(line)

  # -- Assets --

  def list_assets(tenant_id, opts \\ []) do
    base_query =
      from a in Asset,
        where: a.tenant_id == ^tenant_id,
        order_by: [asc: a.code]

    Repo.all(apply_asset_filters(base_query, opts))
  end

  def get_asset!(tenant_id, id, preloads \\ []) do
    Asset
    |> where([a], a.tenant_id == ^tenant_id and a.id == ^id)
    |> Repo.one!()
    |> Repo.preload(preloads)
  end

  def create_asset(attrs) do
    %Asset{}
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  def update_asset(%Asset{} = asset, attrs) do
    asset
    |> Asset.changeset(attrs)
    |> Repo.update()
  end

  def delete_asset(%Asset{} = asset), do: Repo.delete(asset)

  # -- Depreciation schedules --

  def list_depreciation_rows(asset_id) do
    Repo.all(
      from ds in AssetDepreciationSchedule,
        where: ds.asset_id == ^asset_id,
        order_by: [asc: ds.period_date]
    )
  end

  def create_depreciation_row(attrs) do
    %AssetDepreciationSchedule{}
    |> AssetDepreciationSchedule.changeset(attrs)
    |> Repo.insert()
  end

  def update_depreciation_row(%AssetDepreciationSchedule{} = row, attrs) do
    row
    |> AssetDepreciationSchedule.changeset(attrs)
    |> Repo.update()
  end

  def delete_depreciation_row(%AssetDepreciationSchedule{} = row), do: Repo.delete(row)

  # -- Financial accounts --

  def list_financial_accounts(tenant_id) do
    Repo.all(
      from fa in FinancialAccount, where: fa.tenant_id == ^tenant_id, order_by: [asc: fa.name]
    )
  end

  def get_financial_account!(tenant_id, id) do
    Repo.get_by!(FinancialAccount, tenant_id: tenant_id, id: id)
  end

  def create_financial_account(attrs) do
    %FinancialAccount{}
    |> FinancialAccount.changeset(attrs)
    |> Repo.insert()
  end

  def update_financial_account(%FinancialAccount{} = account, attrs) do
    account
    |> FinancialAccount.changeset(attrs)
    |> Repo.update()
  end

  def delete_financial_account(%FinancialAccount{} = account), do: Repo.delete(account)

  # -- Financial transactions --

  def list_financial_transactions(tenant_id, opts \\ []) do
    base_query =
      from ft in FinancialTransaction,
        where: ft.tenant_id == ^tenant_id,
        order_by: [desc: ft.transaction_date]

    Repo.all(apply_transaction_filters(base_query, opts))
  end

  def create_financial_transaction(attrs) do
    %FinancialTransaction{}
    |> FinancialTransaction.changeset(attrs)
    |> Repo.insert()
  end

  def update_financial_transaction(%FinancialTransaction{} = tx, attrs) do
    tx
    |> FinancialTransaction.changeset(attrs)
    |> Repo.update()
  end

  def delete_financial_transaction(%FinancialTransaction{} = tx), do: Repo.delete(tx)

  defp apply_journal_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:is_posted, value}, acc when is_boolean(value) ->
        from je in acc, where: je.is_posted == ^value

      {:from, value}, acc ->
        case to_date(value) do
          {:ok, date} -> from je in acc, where: je.document_date >= ^date
          :error -> acc
        end

      {:to, value}, acc ->
        case to_date(value) do
          {:ok, date} -> from je in acc, where: je.document_date <= ^date
          :error -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"

        from je in acc,
          where:
            ilike(je.entry_number, ^pattern) or
              ilike(je.description, ^pattern)

      _, acc ->
        acc
    end)
  end

  defp to_date(%Date{} = date), do: {:ok, date}
  defp to_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp to_date(_), do: :error

  defp apply_asset_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status in [nil, ""] -> acc
      {:status, status}, acc -> from a in acc, where: a.status == ^status
      {:category, category}, acc when category in [nil, ""] -> acc
      {:category, category}, acc -> from a in acc, where: a.category == ^category
      _, acc -> acc
    end)
  end

  defp apply_transaction_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:financial_account_id, id}, acc when is_integer(id) ->
        from ft in acc, where: ft.financial_account_id == ^id

      {:financial_account_id, id}, acc when is_binary(id) ->
        case Integer.parse(id) do
          {parsed, _} -> from ft in acc, where: ft.financial_account_id == ^parsed
          :error -> acc
        end

      {:direction, dir}, acc when dir in ["in", "out"] ->
        from ft in acc, where: ft.direction == ^dir

      {:from, value}, acc ->
        case to_utc_naive(value, :start) do
          {:ok, datetime} -> from ft in acc, where: ft.transaction_date >= ^datetime
          :error -> acc
        end

      {:to, value}, acc ->
        case to_utc_naive(value, :end) do
          {:ok, datetime} -> from ft in acc, where: ft.transaction_date <= ^datetime
          :error -> acc
        end

      _, acc ->
        acc
    end)
  end

  defp insert_entry_lines(%JournalEntry{} = entry, lines_attrs) do
    lines_attrs
    |> Enum.map(fn attrs ->
      attrs = Map.put(attrs, :tenant_id, entry.tenant_id)
      attrs = Map.put(attrs, :journal_entry_id, entry.id)

      %EntryLine{}
      |> EntryLine.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_batch_result()
  end

  defp handle_batch_result(results) do
    case Enum.split_with(results, fn
           {:ok, _} -> true
           _ -> false
         end) do
      {oks, []} -> {:ok, Enum.map(oks, fn {:ok, record} -> record end)}
      {_, [{:error, changeset} | _]} -> {:error, changeset}
    end
  end

  defp to_utc_naive(%NaiveDateTime{} = naive, _), do: {:ok, naive}

  defp to_utc_naive(%Date{} = date, :start), do: NaiveDateTime.new(date, ~T[00:00:00])

  defp to_utc_naive(%Date{} = date, :end), do: NaiveDateTime.new(date, ~T[23:59:59])

  defp to_utc_naive(value, _), do: parse_naive(value)

  defp parse_naive(value) when is_binary(value), do: NaiveDateTime.from_iso8601(value)
  defp parse_naive(_), do: :error

  # ==========================
  # Posting & Immutability
  # ==========================

  @doc """
  Постинг на запис - след това записът става immutable.
  """
  def post_journal_entry(%JournalEntry{is_posted: true} = entry) do
    {:ok, entry}
  end

  def post_journal_entry(%JournalEntry{} = entry) do
    entry = Repo.preload(entry, :lines)

    with :ok <- validate_entry_balance(entry),
         :ok <- validate_all_accounts_exist(entry) do
      entry
      |> Ecto.Changeset.change(%{
        is_posted: true,
        posted_at: DateTime.utc_now(),
        posted_by_id: entry.created_by_id
      })
      |> Repo.update()
    end
  end

  @doc """
  Отпостинг (Reverse) - създава обратен запис.
  """
  def reverse_journal_entry(%JournalEntry{} = entry, reversal_date, description) do
    entry = Repo.preload(entry, lines: :account)

    reversed_lines =
      Enum.map(entry.lines, fn line ->
        %{
          tenant_id: line.tenant_id,
          account_id: line.account_id,
          # Обръщаме дебит/кредит
          debit_amount: line.credit_amount,
          credit_amount: line.debit_amount,
          currency_code: line.currency_code,
          currency_amount: line.currency_amount,
          exchange_rate: line.exchange_rate,
          vat_amount: D.mult(line.vat_amount, D.new(-1)),
          description: "Сторно: #{line.description}",
          line_order: line.line_order
        }
      end)

    create_journal_entry_with_lines(
      %{
        tenant_id: entry.tenant_id,
        document_date: reversal_date,
        vat_date: reversal_date,
        accounting_date: reversal_date,
        description: description || "Сторно на #{entry.entry_number}",
        created_by_id: entry.created_by_id
      },
      reversed_lines
    )
  end

  defp validate_entry_balance(%JournalEntry{lines: lines}) do
    total_debit =
      lines
      |> Enum.map(& &1.debit_amount)
      |> Enum.reduce(D.new(0), &D.add/2)

    total_credit =
      lines
      |> Enum.map(& &1.credit_amount)
      |> Enum.reduce(D.new(0), &D.add/2)

    if D.equal?(total_debit, total_credit) do
      :ok
    else
      {:error, :unbalanced_entry}
    end
  end

  defp validate_all_accounts_exist(%JournalEntry{lines: lines, tenant_id: tenant_id}) do
    account_ids = Enum.map(lines, & &1.account_id) |> Enum.uniq()

    existing_count =
      Account
      |> where([a], a.tenant_id == ^tenant_id)
      |> where([a], a.id in ^account_ids)
      |> Repo.aggregate(:count)

    if existing_count == length(account_ids) do
      :ok
    else
      {:error, :invalid_accounts}
    end
  end

  # ==========================
  # Trial Balance & Reports
  # ==========================

  @doc """
  Изчислява оборотна ведомост за период.

  Връща списък с:
  - account
  - opening_balance (начално салдо)
  - debit_turnover (дебитен оборот)
  - credit_turnover (кредитен оборот)
  - closing_balance (крайно салдо)
  """
  def trial_balance(tenant_id, from_date, to_date) do
    accounts = list_accounts(tenant_id)

    Enum.map(accounts, fn account ->
      opening = calculate_opening_balance(account.id, from_date)
      {debit_turnover, credit_turnover} = calculate_turnover(account.id, from_date, to_date)

      closing =
        if Account.debit_account?(account) do
          D.add(D.sub(opening, credit_turnover), debit_turnover)
        else
          D.add(D.sub(opening, debit_turnover), credit_turnover)
        end

      %{
        account: account,
        opening_balance: opening,
        debit_turnover: debit_turnover,
        credit_turnover: credit_turnover,
        closing_balance: closing
      }
    end)
  end

  @doc """
  Изчислява салдо на сметка към дата.
  """
  def account_balance(account_id, to_date \\ Date.utc_today()) do
    from_date = ~D[1970-01-01]
    {debit_total, credit_total} = calculate_turnover(account_id, from_date, to_date)

    D.sub(debit_total, credit_total)
  end

  defp calculate_opening_balance(account_id, from_date) do
    {debit_total, credit_total} =
      calculate_turnover(account_id, ~D[1970-01-01], Date.add(from_date, -1))

    D.sub(debit_total, credit_total)
  end

  defp calculate_turnover(account_id, from_date, to_date) do
    query =
      from l in EntryLine,
        join: j in JournalEntry,
        on: l.journal_entry_id == j.id,
        where: l.account_id == ^account_id,
        where: j.is_posted == true,
        where: j.accounting_date >= ^from_date,
        where: j.accounting_date <= ^to_date,
        select: {sum(l.debit_amount), sum(l.credit_amount)}

    case Repo.one(query) do
      {nil, nil} -> {D.new(0), D.new(0)}
      {debit, nil} -> {debit, D.new(0)}
      {nil, credit} -> {D.new(0), credit}
      {debit, credit} -> {debit, credit}
    end
  end

  # ==========================
  # VAT Rates
  # ==========================

  @doc """
  Връща всички ДДС ставки за tenant.
  """
  def list_vat_rates(tenant_id) do
    VatRate
    |> where([v], v.tenant_id == ^tenant_id)
    |> where([v], v.is_active == true)
    |> order_by([v], desc: v.rate)
    |> Repo.all()
  end

  @doc """
  Връща ДДС ставка по ID.
  """
  def get_vat_rate!(tenant_id, id) do
    VatRate
    |> where([v], v.tenant_id == ^tenant_id)
    |> where([v], v.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Взима ДДС ставка по ID без tenant_id (за cache).
  """
  def get_vat_rate(id) do
    Repo.get(VatRate, id)
  end

  @doc """
  Взима ДДС ставка по код.
  """
  def get_vat_rate_by_code(code, tenant_id) do
    Repo.get_by(VatRate, code: code, tenant_id: tenant_id, is_active: true)
  end

  @doc """
  Създава нова ДДС ставка.
  """
  def create_vat_rate(tenant_id, attrs) do
    attrs = Map.put(attrs, "tenant_id", tenant_id)

    %VatRate{}
    |> VatRate.changeset(attrs)
    |> Repo.insert()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_vat_rate/1)
  end

  @doc """
  Обновява ДДС ставка.
  """
  def update_vat_rate(%VatRate{} = rate, attrs) do
    rate
    |> VatRate.changeset(attrs)
    |> Repo.update()
    |> tap(&CyberCore.Cache.Invalidator.invalidate_vat_rate/1)
  end

  @doc """
  Изтрива ДДС ставка.
  """
  def delete_vat_rate(%VatRate{} = rate) do
    result = Repo.delete(rate)
    CyberCore.Cache.Invalidator.invalidate_vat_rates()
    result
  end

  # ==========================
  # Fixed Assets - Wrapper functions
  # ==========================

  @doc """
  Wrapper for FixedAssets context - change asset
  """
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end
  
  @doc """
  Задава начално салдо за счетоводна сметка.
  
  Тази функция задава началното салдо за дадена сметка, което ще се използва
  при изчисляване на оборотната ведомост и други отчети.
  """
  def set_account_opening_balance(tenant_id, account_id, balance) do
    account = get_account!(tenant_id, account_id)

    result = account
    |> Account.changeset(%{opening_balance: balance})
    |> Repo.update()

    # Създаване на счетоводен запис за началното салдо, ако е необходимо
    case result do
      {:ok, updated_account} ->
        if not Decimal.equal?(balance, Decimal.new(0)) do
          create_opening_journal_entry_for_account(tenant_id, updated_account, balance)
        end
        {:ok, updated_account}
      error -> error
    end
  end
  
  @doc """
  Премахва началното салдо за сметка.
  """
  def remove_account_opening_balance(tenant_id, account_id) do
    account = get_account!(tenant_id, account_id)
    
    account
    |> Account.changeset(%{opening_balance: Decimal.new(0)})
    |> Repo.update()
  end
  
  defp create_opening_journal_entry_for_account(tenant_id, account, balance) do
    equity_account_id = get_equity_account_id(tenant_id)
    today = Date.utc_today()

    lines = cond do
      Decimal.gt?(balance, Decimal.new(0)) ->
        # Положително салдо - дебитно салдо
        [
          %{
            account_id: account.id,
            debit_amount: balance,
            credit_amount: Decimal.new(0),
            description: "Начално дебитно салдо"
          },
          %{
            account_id: equity_account_id,
            debit_amount: Decimal.new(0),
            credit_amount: balance,
            description: "Начално салдо за сметка #{account.code}"
          }
        ]

      Decimal.lt?(balance, Decimal.new(0)) ->
        # Отрицателно салдо - кредитно салдо
        abs_balance = Decimal.abs(balance)
        [
          %{
            account_id: account.id,
            debit_amount: Decimal.new(0),
            credit_amount: abs_balance,
            description: "Начално кредитно салдо"
          },
          %{
            account_id: equity_account_id,
            debit_amount: abs_balance,
            credit_amount: Decimal.new(0),
            description: "Начално салдо за сметка #{account.code}"
          }
        ]

      true ->
        []
    end

    if lines != [] do
      create_journal_entry_with_lines(
        %{
          tenant_id: tenant_id,
          document_type: "opening_balance",
          document_number: "OA-#{account.id}",
          document_date: today,
          description: "Начално салдо за сметка #{account.code} - #{account.name}",
          accounting_date: today,
          is_posted: true,
          source_document_id: account.id,
          source_document_type: "AccountOpeningBalance"
        },
        lines
      )
    else
      {:ok, nil}
    end
  end

  defp get_equity_account_id(tenant_id) do
    # Търсене на стандартната капиталова сметка
    case get_account_by_code("801", tenant_id) do
      nil -> raise "Не е намерена сметка 801 за уставен капитал"
      account -> account.id
    end
  end

end
