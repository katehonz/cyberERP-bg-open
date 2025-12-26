defmodule CyberCore.Bank.BankService do
  @moduledoc """
  Основен сервис за банкови операции.

  Координира:
  - Salt Edge синхронизация
  - Ръчен импорт на файлове
  - Създаване на дневни записи
  """

  alias CyberCore.Repo
  alias CyberCore.Bank.{BankProfile, BankConnection, BankImport, BankTransaction}
  alias CyberCore.Bank.SaltEdgeClient
  alias CyberCore.Accounting

  require Logger

  @doc """
  Създава новa Salt Edge връзка за tenant.
  """
  def create_saltedge_connection(tenant_id, _user_id, return_url \\ nil) do
    Repo.transaction(fn ->
      # 1. Създай customer в Salt Edge
      {:ok, customer_response} = SaltEdgeClient.create_customer(tenant_id)
      customer_id = customer_response["data"]["id"]

      # 2. Създай connect session
      {:ok, session_response} =
        SaltEdgeClient.create_connect_session(customer_id, return_url: return_url)

      connect_url = session_response["data"]["connect_url"]

      %{
        customer_id: customer_id,
        connect_url: connect_url
      }
    end)
  end

  @doc """
  Обработва callback от Salt Edge след успешна връзка.
  """
  def handle_saltedge_callback(connection_id, tenant_id, user_id) do
    Repo.transaction(fn ->
      # 1. Вземи информация за connection
      {:ok, connection_data} = SaltEdgeClient.get_connection(connection_id)
      connection_info = connection_data["data"]

      # 2. Вземи accounts
      {:ok, accounts_data} = SaltEdgeClient.list_accounts(connection_id)
      accounts = accounts_data["data"]

      # 3. Запази connection в БД
      bank_connection =
        %BankConnection{}
        |> BankConnection.changeset(%{
          tenant_id: tenant_id,
          saltedge_connection_id: connection_id,
          saltedge_customer_id: connection_info["customer_id"],
          provider_code: connection_info["provider_code"],
          provider_name: connection_info["provider_name"],
          status: connection_info["status"],
          consent_expires_at: parse_datetime(connection_info["consent_expires_at"]),
          last_success_at: DateTime.utc_now(),
          metadata: connection_info,
          created_by_id: user_id
        })
        |> Repo.insert!()

      # 4. Създай bank profiles за всеки account
      bank_profiles =
        Enum.map(accounts, fn account ->
          create_bank_profile_from_account(account, bank_connection, tenant_id, user_id)
        end)

      %{
        connection: bank_connection,
        profiles: bank_profiles
      }
    end)
  end

  @doc """
  Синхронизира транзакции от Salt Edge.
  """
  def sync_saltedge_transactions(bank_profile_id, opts \\ []) do
    Repo.transaction(fn ->
      bank_profile = Repo.get!(BankProfile, bank_profile_id) |> Repo.preload(:bank_connection)

      if is_nil(bank_profile.saltedge_account_id) do
        raise "Bank profile не е свързан със Salt Edge"
      end

      # 1. Refresh connection
      {:ok, _} =
        SaltEdgeClient.refresh_connection(
          bank_profile.saltedge_connection_id,
          from_date: opts[:from_date]
        )

      # 2. Изчакай малко да се обновят данните
      Process.sleep(5000)

      # 3. Fetch transactions
      {:ok, transactions_data} =
        SaltEdgeClient.list_transactions(
          bank_profile.saltedge_account_id,
          from_date: opts[:from_date],
          to_date: opts[:to_date]
        )

      transactions = transactions_data["data"]

      # 4. Създай bank import запис
      bank_import =
        %BankImport{}
        |> BankImport.changeset(%{
          tenant_id: bank_profile.tenant_id,
          bank_profile_id: bank_profile.id,
          import_type: "saltedge_auto",
          import_format: "saltedge_api",
          imported_at: DateTime.utc_now(),
          period_from: opts[:from_date] && Date.from_iso8601!(opts[:from_date]),
          period_to: (opts[:to_date] && Date.from_iso8601!(opts[:to_date])) || Date.utc_today(),
          status: "in_progress"
        })
        |> Repo.insert!()

      # 5. Запази транзакциите
      bank_transactions =
        Enum.map(transactions, fn transaction ->
          create_bank_transaction(transaction, bank_import, bank_profile)
        end)

      # 6. Актуализирай статистики
      stats = calculate_import_stats(bank_transactions)

      bank_import =
        bank_import
        |> BankImport.mark_completed(stats)
        |> Repo.update!()

      # 7. Актуализирай last_synced_at
      bank_profile
      |> Ecto.Changeset.change(%{last_synced_at: DateTime.utc_now()})
      |> Repo.update!()

      %{
        import: bank_import,
        transactions: bank_transactions
      }
    end)
  end

  @doc """
  Импортира файл с банкови извлечения.
  """
  def import_bank_file(bank_profile_id, file_path, user_id, _opts \\ []) do
    Repo.transaction(fn ->
      bank_profile = Repo.get!(BankProfile, bank_profile_id)

      # 1. Парсни файла според формата
      parser = get_parser(bank_profile.import_format)
      {:ok, parsed_data} = parser.parse_file(file_path)

      # 2. Създай bank import
      bank_import =
        %BankImport{}
        |> BankImport.changeset(%{
          tenant_id: bank_profile.tenant_id,
          bank_profile_id: bank_profile.id,
          import_type: "file_upload",
          file_name: Path.basename(file_path),
          import_format: bank_profile.import_format,
          imported_at: DateTime.utc_now(),
          period_from: parsed_data.period_from,
          period_to: parsed_data.period_to,
          status: "in_progress",
          created_by_id: user_id
        })
        |> Repo.insert!()

      # 3. Създай транзакции
      bank_transactions =
        Enum.map(parsed_data.transactions, fn transaction_data ->
          create_bank_transaction_from_file(transaction_data, bank_import, bank_profile)
        end)

      # 4. Актуализирай статистики
      stats = calculate_import_stats(bank_transactions)

      bank_import =
        bank_import
        |> BankImport.mark_completed(stats)
        |> Repo.update!()

      %{
        import: bank_import,
        transactions: bank_transactions
      }
    end)
  rescue
    error ->
      Logger.error("Bank import failed: #{inspect(error)}")
      {:error, "Import failed: #{Exception.message(error)}"}
  end

  @doc """
  Създава дневни записи от банкови транзакции.
  """
  def create_journal_entries(bank_import_id, user_id) do
    bank_import =
      Repo.get!(BankImport, bank_import_id) |> Repo.preload([:bank_profile, :bank_transactions])

    bank_profile = bank_import.bank_profile

    Repo.transaction(fn ->
      journal_entries =
        bank_import.bank_transactions
        |> Enum.reject(& &1.is_processed)
        |> Enum.map(fn transaction ->
          create_journal_entry_from_transaction(transaction, bank_profile, user_id)
        end)

      # Маркирай транзакциите като обработени
      Enum.each(bank_import.bank_transactions, fn transaction ->
        transaction
        |> Ecto.Changeset.change(%{
          is_processed: true,
          processed_at: DateTime.utc_now()
        })
        |> Repo.update!()
      end)

      journal_entries
    end)
  end

  # Private Functions

  defp create_bank_profile_from_account(account, bank_connection, _tenant_id, _user_id) do
    # TODO: Тук трябва да има UI за избор на bank_account и buffer_account
    # За момента връщаме само данните
    %{
      name: account["name"],
      iban: account["iban"],
      currency_code: account["currency_code"],
      saltedge_connection_id: bank_connection.saltedge_connection_id,
      saltedge_account_id: account["id"],
      balance: account["balance"]
    }
  end

  defp create_bank_transaction(transaction, bank_import, bank_profile) do
    %BankTransaction{}
    |> Ecto.Changeset.change(%{
      bank_import_id: bank_import.id,
      bank_profile_id: bank_profile.id,
      tenant_id: bank_profile.tenant_id,
      transaction_id: transaction["id"],
      booking_date: Date.from_iso8601!(transaction["made_on"]),
      value_date: transaction["posted_on"] && Date.from_iso8601!(transaction["posted_on"]),
      amount: abs(Decimal.new(to_string(transaction["amount"]))),
      currency: transaction["currency_code"],
      is_credit: Decimal.new(to_string(transaction["amount"])) |> Decimal.positive?(),
      description: transaction["description"],
      reference: transaction["extra"]["id"],
      counterpart_name: transaction["extra"]["payee"],
      counterpart_iban: transaction["extra"]["account_number"],
      metadata: transaction
    })
    |> Repo.insert!()
  end

  defp create_bank_transaction_from_file(transaction_data, bank_import, bank_profile) do
    %BankTransaction{}
    |> Ecto.Changeset.change(%{
      bank_import_id: bank_import.id,
      bank_profile_id: bank_profile.id,
      tenant_id: bank_profile.tenant_id,
      booking_date: transaction_data.booking_date,
      value_date: transaction_data.value_date,
      amount: transaction_data.amount,
      currency: transaction_data.currency,
      is_credit: transaction_data.is_credit,
      description: transaction_data.description,
      reference: transaction_data.reference,
      counterpart_name: transaction_data.counterpart_name,
      counterpart_iban: transaction_data.counterpart_iban
    })
    |> Repo.insert!()
  end

  defp create_journal_entry_from_transaction(transaction, bank_profile, user_id) do
    # Създаване на дневен запис
    # Dt: Банкова сметка (bank_account_id)
    # Ct: Buffer сметка (buffer_account_id) - за сверка

    description = """
    Банкова транзакция: #{transaction.description}
    #{if transaction.counterpart_name, do: "Контрагент: #{transaction.counterpart_name}", else: ""}
    Референция: #{transaction.reference}
    """

    lines =
      if transaction.is_credit do
        [
          %{
            accounting_account_id: bank_profile.bank_account_id,
            debit: transaction.amount,
            credit: Decimal.new(0)
          },
          %{
            accounting_account_id: bank_profile.buffer_account_id,
            debit: Decimal.new(0),
            credit: transaction.amount
          }
        ]
      else
        [
          %{
            accounting_account_id: bank_profile.buffer_account_id,
            debit: transaction.amount,
            credit: Decimal.new(0)
          },
          %{
            accounting_account_id: bank_profile.bank_account_id,
            debit: Decimal.new(0),
            credit: transaction.amount
          }
        ]
      end

    {:ok, journal_entry} =
      Accounting.create_journal_entry(%{
        tenant_id: bank_profile.tenant_id,
        document_date: transaction.booking_date, # Use booking_date as document_date
        accounting_date: transaction.booking_date, # Use booking_date as accounting_date
        description: description,
        document_number: "BANK-#{transaction.id}", # document_number is used for this
        created_by_id: user_id,
        source_document_id: transaction.id,
        source_document_type: "BankTransaction"
      })

    # Create individual entry lines
    Enum.each(lines, fn line_attrs ->
      line_attrs = Map.put(line_attrs, :journal_entry_id, journal_entry.id)
      line_attrs = Map.put(line_attrs, :tenant_id, journal_entry.tenant_id) # Ensure tenant_id is set
      {:ok, _entry_line} = Accounting.create_entry_line(line_attrs)
    end)

    # Актуализирай транзакцията
    transaction
    |> Ecto.Changeset.change(%{journal_entry_id: journal_entry.id})
    |> Repo.update!()

    journal_entry
  end

  defp calculate_import_stats(bank_transactions) do
    transactions_count = length(bank_transactions)

    {total_credit, total_debit} =
      Enum.reduce(bank_transactions, {Decimal.new(0), Decimal.new(0)}, fn transaction,
                                                                          {credit, debit} ->
        if transaction.is_credit do
          {Decimal.add(credit, transaction.amount), debit}
        else
          {credit, Decimal.add(debit, transaction.amount)}
        end
      end)

    %{
      transactions_count: transactions_count,
      total_credit: total_credit,
      total_debit: total_debit,
      created_journal_entries: 0,
      journal_entry_ids: []
    }
  end

  defp get_parser("mt940"), do: CyberCore.Bank.Parsers.MT940
  defp get_parser("camt053_wise"), do: CyberCore.Bank.Parsers.CAMT053Wise
  defp get_parser("camt053_revolut"), do: CyberCore.Bank.Parsers.CAMT053Revolut
  defp get_parser("camt053_paysera"), do: CyberCore.Bank.Parsers.CAMT053Paysera
  defp get_parser("ccb_csv"), do: CyberCore.Bank.Parsers.CCBCSV
  defp get_parser("postbank_xml"), do: CyberCore.Bank.Parsers.PostbankXML
  defp get_parser("obb_xml"), do: CyberCore.Bank.Parsers.OBBXML
  defp get_parser(format), do: raise("Unsupported import format: #{format}")

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end
end
