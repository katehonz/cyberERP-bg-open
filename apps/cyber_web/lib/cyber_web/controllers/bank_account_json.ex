defmodule CyberWeb.BankAccountJSON do
  @moduledoc """
  JSON сериализация за BankAccount ресурс.
  """

  alias CyberCore.Bank.BankAccount

  @doc """
  Рендерира списък от банкови сметки.
  """
  def index(%{bank_accounts: bank_accounts}) do
    %{data: for(account <- bank_accounts, do: data(account))}
  end

  @doc """
  Рендерира една банкова сметка.
  """
  def show(%{bank_account: bank_account}) do
    %{data: data(bank_account)}
  end

  defp data(%BankAccount{} = account) do
    %{
      id: account.id,
      tenant_id: account.tenant_id,
      account_no: account.account_no,
      iban: account.iban,
      bic: account.bic,
      account_type: account.account_type,
      bank_name: account.bank_name,
      bank_code: account.bank_code,
      branch_name: account.branch_name,
      currency: account.currency,
      initial_balance: account.initial_balance,
      current_balance: account.current_balance,
      is_active: account.is_active,
      notes: account.notes,
      inserted_at: account.inserted_at,
      updated_at: account.updated_at
    }
  end
end
