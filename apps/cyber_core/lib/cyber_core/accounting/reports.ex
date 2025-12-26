defmodule CyberCore.Accounting.Reports do
  @moduledoc """
  Интелигентни счетоводни отчети.

  Поддържа:
  - Дневник на операциите (Transaction Log)
  - Главна книга (General Ledger)
  - Хронологичен регистър (Chronological Report)
  - Главна книга по дебит/кредит (BG General Ledger)
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Accounting.{Account, JournalEntry, EntryLine}
  alias CyberCore.Contacts.Contact
  alias Decimal, as: D

  @doc """
  Генерира дневник на операциите.

  ## Параметри
    - tenant_id: ID на организацията
    - from_date: Начална дата
    - to_date: Крайна дата
    - account_id: (опционално) Филтър по сметка

  ## Връща
  Списък с всички записи хронологично подредени
  """
  def transaction_log(tenant_id, from_date, to_date, opts \\ []) do
    account_id = Keyword.get(opts, :account_id)

    base_query =
      from line in EntryLine,
        join: entry in JournalEntry,
        on: line.journal_entry_id == entry.id,
        join: account in Account,
        on: line.account_id == account.id,
        left_join: contact in Contact,
        on: line.contact_id == contact.id,
        where: entry.tenant_id == ^tenant_id,
        where: entry.accounting_date >= ^from_date,
        where: entry.accounting_date <= ^to_date,
        order_by: [
          asc: entry.accounting_date,
          asc: entry.entry_number,
          asc: line.line_order
        ],
        select: %{
          date: entry.accounting_date,
          entry_number: entry.entry_number,
          document_number: entry.document_number,
          description: coalesce(line.description, entry.description),
          account_code: account.code,
          account_name: account.name,
          debit_amount: line.debit_amount,
          credit_amount: line.credit_amount,
          counterpart_name: contact.name
        }

    query =
      if account_id do
        where(base_query, [line], line.account_id == ^account_id)
      else
        base_query
      end

    Repo.all(query)
  end

  @doc """
  Генерира главна книга - детайлен отчет по сметки.

  ## Параметри
    - tenant_id: ID на организацията
    - from_date: Начална дата
    - to_date: Крайна дата
    - account_id: (опционално) Филтър по сметка

  ## Връща
  Списък от сметки с техните операции, начални и крайни салда
  """
  def general_ledger(tenant_id, from_date, to_date, opts \\ []) do
    account_id = Keyword.get(opts, :account_id)

    accounts =
      if account_id do
        [CyberCore.Accounting.get_account!(tenant_id, account_id)]
      else
        CyberCore.Accounting.list_accounts(tenant_id)
        |> Enum.filter(& &1.is_active)
      end

    Enum.map(accounts, fn account ->
      opening_balance = calculate_opening_balance(account.id, from_date)
      entries = get_account_entries(account.id, from_date, to_date)

      {total_debits, total_credits, entries_with_balance} =
        calculate_running_balance(entries, opening_balance)

      closing_balance = D.add(D.sub(opening_balance, total_credits), total_debits)

      %{
        account_id: account.id,
        account_code: account.code,
        account_name: account.name,
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        total_debits: total_debits,
        total_credits: total_credits,
        entries: entries_with_balance
      }
    end)
    |> Enum.filter(fn acc ->
      # Показваме само сметки с операции или салда
      length(acc.entries) > 0 or
        !D.equal?(acc.opening_balance, D.new(0)) or
        !D.equal?(acc.closing_balance, D.new(0))
    end)
  end

  @doc """
  Генерира хронологичен регистър на счетоводните операции.

  Показва дебит/кредит сметки заедно с валутна информация.
  """
  def chronological_report(tenant_id, from_date, to_date, _opts \\ []) do
    query =
      from entry in JournalEntry,
        join: debit_line in EntryLine,
        on: debit_line.journal_entry_id == entry.id,
        join: credit_line in EntryLine,
        on: credit_line.journal_entry_id == entry.id,
        join: debit_account in Account,
        on: debit_line.account_id == debit_account.id,
        join: credit_account in Account,
        on: credit_line.account_id == credit_account.id,
        where: entry.tenant_id == ^tenant_id,
        where: entry.accounting_date >= ^from_date,
        where: entry.accounting_date <= ^to_date,
        where: debit_line.debit_amount > 0,
        where: credit_line.credit_amount > 0,
        where: debit_line.debit_amount == credit_line.credit_amount,
        order_by: [
          asc: entry.accounting_date,
          asc: entry.entry_number
        ],
        select: %{
          date: entry.accounting_date,
          debit_account_code: debit_account.code,
          debit_account_name: debit_account.name,
          credit_account_code: credit_account.code,
          credit_account_name: credit_account.name,
          amount: debit_line.debit_amount,
          debit_currency_amount: debit_line.currency_amount,
          debit_currency_code: debit_line.currency_code,
          credit_currency_amount: credit_line.currency_amount,
          credit_currency_code: credit_line.currency_code,
          document_type: entry.vat_document_type,
          document_date: entry.document_date,
          description: entry.description
        }

    entries = Repo.all(query)

    total_amount =
      entries
      |> Enum.reduce(D.new(0), fn entry, acc ->
        D.add(acc, entry.amount)
      end)

    %{
      entries: entries,
      total_amount: total_amount
    }
  end

  @doc """
  Генерира главна книга по български стандарт.

  Групира по дебитни и кредитни сметки отделно.
  """
  def bg_general_ledger(tenant_id, from_date, to_date, _opts \\ []) do
    # Групиране по дебит сметки
    by_debit_query =
      from line in EntryLine,
        join: entry in JournalEntry,
        on: line.journal_entry_id == entry.id,
        join: debit_account in Account,
        on: line.account_id == debit_account.id,
        join: credit_line in EntryLine,
        on: credit_line.journal_entry_id == entry.id and credit_line.id != line.id,
        join: credit_account in Account,
        on: credit_line.account_id == credit_account.id,
        where: entry.tenant_id == ^tenant_id,
        where: entry.accounting_date >= ^from_date,
        where: entry.accounting_date <= ^to_date,
        where: line.debit_amount > 0,
        where: credit_line.credit_amount > 0,
        group_by: [
          debit_account.id,
          debit_account.code,
          debit_account.name,
          credit_account.id,
          credit_account.code,
          credit_account.name
        ],
        select: %{
          debit_account_id: debit_account.id,
          debit_account_code: debit_account.code,
          debit_account_name: debit_account.name,
          credit_account_code: credit_account.code,
          credit_account_name: credit_account.name,
          amount: sum(line.debit_amount)
        }

    by_debit_entries = Repo.all(by_debit_query)

    # Групиране по дебит сметка
    by_debit =
      by_debit_entries
      |> Enum.group_by(&{&1.debit_account_id, &1.debit_account_code, &1.debit_account_name})
      |> Enum.map(fn {{_id, code, name}, entries} ->
        total =
          entries
          |> Enum.reduce(D.new(0), fn e, acc -> D.add(acc, e.amount) end)

        %{
          debit_account_code: code,
          debit_account_name: name,
          entries:
            Enum.map(entries, fn e ->
              %{
                credit_account_code: e.credit_account_code,
                credit_account_name: e.credit_account_name,
                amount: e.amount
              }
            end),
          total_amount: total
        }
      end)
      |> Enum.sort_by(& &1.debit_account_code)

    # Групиране по кредит сметки
    by_credit_query =
      from line in EntryLine,
        join: entry in JournalEntry,
        on: line.journal_entry_id == entry.id,
        join: credit_account in Account,
        on: line.account_id == credit_account.id,
        join: debit_line in EntryLine,
        on: debit_line.journal_entry_id == entry.id and debit_line.id != line.id,
        join: debit_account in Account,
        on: debit_line.account_id == debit_account.id,
        where: entry.tenant_id == ^tenant_id,
        where: entry.accounting_date >= ^from_date,
        where: entry.accounting_date <= ^to_date,
        where: line.credit_amount > 0,
        where: debit_line.debit_amount > 0,
        group_by: [
          credit_account.id,
          credit_account.code,
          credit_account.name,
          debit_account.id,
          debit_account.code,
          debit_account.name
        ],
        select: %{
          credit_account_id: credit_account.id,
          credit_account_code: credit_account.code,
          credit_account_name: credit_account.name,
          debit_account_code: debit_account.code,
          debit_account_name: debit_account.name,
          amount: sum(line.credit_amount)
        }

    by_credit_entries = Repo.all(by_credit_query)

    # Групиране по кредит сметка
    by_credit =
      by_credit_entries
      |> Enum.group_by(&{&1.credit_account_id, &1.credit_account_code, &1.credit_account_name})
      |> Enum.map(fn {{_id, code, name}, entries} ->
        total =
          entries
          |> Enum.reduce(D.new(0), fn e, acc -> D.add(acc, e.amount) end)

        %{
          credit_account_code: code,
          credit_account_name: name,
          entries:
            Enum.map(entries, fn e ->
              %{
                debit_account_code: e.debit_account_code,
                debit_account_name: e.debit_account_name,
                amount: e.amount
              }
            end),
          total_amount: total
        }
      end)
      |> Enum.sort_by(& &1.credit_account_code)

    %{
      by_debit: by_debit,
      by_credit: by_credit
    }
  end

  # Private helpers

  defp calculate_opening_balance(account_id, from_date) do
    query =
      from line in EntryLine,
        join: entry in JournalEntry,
        on: line.journal_entry_id == entry.id,
        where: line.account_id == ^account_id,
        where: entry.accounting_date < ^from_date,
        select: %{
          total_debit: sum(line.debit_amount),
          total_credit: sum(line.credit_amount)
        }

    result = Repo.one(query)

    total_debit = result.total_debit || D.new(0)
    total_credit = result.total_credit || D.new(0)

    D.sub(total_debit, total_credit)
  end

  defp get_account_entries(account_id, from_date, to_date) do
    query =
      from line in EntryLine,
        join: entry in JournalEntry,
        on: line.journal_entry_id == entry.id,
        left_join: contact in Contact,
        on: line.contact_id == contact.id,
        where: line.account_id == ^account_id,
        where: entry.accounting_date >= ^from_date,
        where: entry.accounting_date <= ^to_date,
        order_by: [
          asc: entry.accounting_date,
          asc: entry.entry_number,
          asc: line.line_order
        ],
        select: %{
          date: entry.accounting_date,
          entry_number: entry.entry_number,
          document_number: entry.document_number,
          description: coalesce(line.description, entry.description),
          debit_amount: line.debit_amount,
          credit_amount: line.credit_amount,
          counterpart_name: contact.name
        }

    Repo.all(query)
  end

  defp calculate_running_balance(entries, opening_balance) do
    {total_debits, total_credits, reversed_entries} =
      Enum.reduce(entries, {D.new(0), D.new(0), []}, fn entry, {debits, credits, acc} ->
        new_debits = D.add(debits, entry.debit_amount)
        new_credits = D.add(credits, entry.credit_amount)

        balance = D.add(D.sub(opening_balance, new_credits), new_debits)

        entry_with_balance = Map.put(entry, :balance, balance)

        {new_debits, new_credits, [entry_with_balance | acc]}
      end)

    {total_debits, total_credits, Enum.reverse(reversed_entries)}
  end
end
