defmodule CyberCore.Bank do
  @moduledoc """
  Контекст за банкови операции и управление на банкови сметки.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo
  alias CyberCore.Bank.{BankAccount, BankTransaction, BankStatement}

  # -- Bank Accounts --

  def list_bank_accounts(tenant_id, opts \\ []) do
    query =
      from ba in BankAccount,
        where: ba.tenant_id == ^tenant_id,
        order_by: [asc: ba.account_no]

    Repo.all(apply_account_filters(query, opts))
  end

  def get_bank_account!(tenant_id, id) do
    Repo.get_by!(BankAccount, tenant_id: tenant_id, id: id)
  end

  def create_bank_account(attrs) do
    %BankAccount{}
    |> BankAccount.changeset(attrs)
    |> Repo.insert()
  end

  def update_bank_account(%BankAccount{} = account, attrs) do
    account
    |> BankAccount.changeset(attrs)
    |> Repo.update()
  end

  def delete_bank_account(%BankAccount{} = account), do: Repo.delete(account)

  defp apply_account_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:is_active, value}, acc when is_boolean(value) ->
        from ba in acc, where: ba.is_active == ^value

      {:currency, currency}, acc when currency != nil ->
        from ba in acc, where: ba.currency == ^currency

      _, acc ->
        acc
    end)
  end

  # -- Bank Transactions --

  def list_bank_transactions(tenant_id, opts \\ []) do
    query =
      from bt in BankTransaction,
        where: bt.tenant_id == ^tenant_id,
        order_by: [desc: bt.transaction_date],
        preload: [:bank_account, :contact]

    Repo.all(apply_transaction_filters(query, opts))
  end

  def get_bank_transaction!(tenant_id, id) do
    BankTransaction
    |> where([bt], bt.tenant_id == ^tenant_id and bt.id == ^id)
    |> preload([:bank_account, :contact])
    |> Repo.one!()
  end

  def create_bank_transaction(attrs) do
    Repo.transaction(fn ->
      with {:ok, transaction} <- insert_bank_transaction(attrs),
           :ok <- update_account_balance(transaction) do
        Repo.preload(transaction, [:bank_account, :contact])
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_bank_transaction(attrs) do
    %BankTransaction{}
    |> BankTransaction.changeset(attrs)
    |> Repo.insert()
  end

  defp update_account_balance(%BankTransaction{} = transaction) do
    account = Repo.get!(BankAccount, transaction.bank_account_id)
    amount = transaction.amount

    new_balance =
      if transaction.is_credit do
        Decimal.add(account.current_balance, amount)
      else
        Decimal.sub(account.current_balance, amount)
      end

    account
    |> BankAccount.changeset(%{current_balance: new_balance})
    |> Repo.update()

    :ok
  end

  def update_bank_transaction(%BankTransaction{} = transaction, attrs) do
    transaction
    |> BankTransaction.changeset(attrs)
    |> Repo.update()
  end

  def delete_bank_transaction(%BankTransaction{} = transaction), do: Repo.delete(transaction)

  def reconcile_transaction(%BankTransaction{} = transaction) do
    update_bank_transaction(transaction, %{is_reconciled: true})
  end

  defp apply_transaction_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:bank_account_id, id}, acc when is_integer(id) ->
        from bt in acc, where: bt.bank_account_id == ^id

      {:transaction_type, type}, acc when type != nil ->
        from bt in acc, where: bt.transaction_type == ^type

      {:status, status}, acc when status != nil ->
        from bt in acc, where: bt.status == ^status

      {:is_reconciled, value}, acc when is_boolean(value) ->
        from bt in acc, where: bt.is_reconciled == ^value

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from bt in acc, where: bt.transaction_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from bt in acc, where: bt.transaction_date <= ^date
          _ -> acc
        end

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"

        from bt in acc,
          where:
            ilike(bt.description, ^pattern) or
              ilike(bt.counterparty_name, ^pattern) or
              ilike(bt.transaction_no, ^pattern)

      _, acc ->
        acc
    end)
  end

  # -- Bank Statements --

  def list_bank_statements(tenant_id, opts \\ []) do
    query =
      from bs in BankStatement,
        where: bs.tenant_id == ^tenant_id,
        order_by: [desc: bs.statement_date],
        preload: [:bank_account]

    Repo.all(apply_statement_filters(query, opts))
  end

  def get_bank_statement!(tenant_id, id) do
    BankStatement
    |> where([bs], bs.tenant_id == ^tenant_id and bs.id == ^id)
    |> preload(:bank_account)
    |> Repo.one!()
  end

  def create_bank_statement(attrs) do
    %BankStatement{}
    |> BankStatement.changeset(attrs)
    |> Repo.insert()
  end

  def update_bank_statement(%BankStatement{} = statement, attrs) do
    statement
    |> BankStatement.changeset(attrs)
    |> Repo.update()
  end

  def delete_bank_statement(%BankStatement{} = statement), do: Repo.delete(statement)

  defp apply_statement_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:bank_account_id, id}, acc when is_integer(id) ->
        from bs in acc, where: bs.bank_account_id == ^id

      {:status, status}, acc when status != nil ->
        from bs in acc, where: bs.status == ^status

      {:from, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from bs in acc, where: bs.statement_date >= ^date
          _ -> acc
        end

      {:to, value}, acc ->
        case Date.from_iso8601(value) do
          {:ok, date} -> from bs in acc, where: bs.statement_date <= ^date
          _ -> acc
        end

      _, acc ->
        acc
    end)
  end
end
