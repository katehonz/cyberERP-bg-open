defmodule CyberWeb.BankTransactionJSON do
  @moduledoc """
  JSON сериализация за BankTransaction ресурс.
  """

  alias CyberCore.Bank.BankTransaction

  @doc """
  Рендерира списък от банкови транзакции.
  """
  def index(%{bank_transactions: bank_transactions}) do
    %{data: for(transaction <- bank_transactions, do: data(transaction))}
  end

  @doc """
  Рендерира една банкова транзакция.
  """
  def show(%{bank_transaction: bank_transaction}) do
    %{data: data(bank_transaction)}
  end

  defp data(%BankTransaction{} = transaction) do
    base_data = %{
      id: transaction.id,
      tenant_id: transaction.tenant_id,
      bank_profile_id: transaction.bank_profile_id,
      transaction_id: transaction.transaction_id,
      booking_date: transaction.booking_date,
      value_date: transaction.value_date,
      amount: transaction.amount,
      currency: transaction.currency,
      counterpart_name: transaction.counterpart_name,
      counterpart_iban: transaction.counterpart_iban,
      counterpart_bic: transaction.counterpart_bic,
      description: transaction.description,
      reference: transaction.reference,
      is_processed: transaction.is_processed,
      inserted_at: transaction.inserted_at,
      updated_at: transaction.updated_at
    }

    # Добавяме bank_profile ако е зареден
    if Ecto.assoc_loaded?(transaction.bank_profile) do
      Map.put(base_data, :bank_profile, %{
        id: transaction.bank_profile.id,
        name: transaction.bank_profile.name
        # add other fields from bank_profile if needed
      })
    else
      base_data
    end
  end
end
