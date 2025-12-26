defmodule CyberCore.Contacts.ContactBankAccountMapper do
  @moduledoc """
  Интелигентно мапиране на банкови сметки на ДОСТАВЧИЦИ от фактури за покупки.

  **ВАЖНО**: Използва се САМО за ПОКУПКИ (purchase/supplier invoices)!

  Автоматично извлича и съхранява банкови сметки (IBAN) на ДОСТАВЧИЦИ,
  за да може после банковия модул лесно да обработва ИЗХОДЯЩИ плащания.

  ## Workflow - Само за Purchase Invoices

  1. **Извличане от supplier invoice (покупка)**:
     - Azure Form Recognizer извлича vendor_bank_iban от фактурата на доставчика
     - При одобрение на фактурата, записваме IBAN-а в contact_bank_accounts
     - Ако IBAN-ът вече съществува → увеличаваме times_seen

  2. **Автоматично матчване при ИЗХОДЯЩО плащане**:
     - При импорт на bank_transaction с amount < 0 (изходящо)
     - Имаме correspondent_account (IBAN на доставчика)
     - Търсим този IBAN в contact_bank_accounts
     - Намираме доставчика автоматично
     - Предлагаме неплатени supplier invoices за матчване

  ## НЕ се използва за продажби

  При sales invoices НЕ извличаме банкова сметка на клиента.
  При получаване на плащания (amount > 0) матчваме по:
  - Наша банкова сметка (от bank_accounts)
  - Invoice number в описанието
  - Amount

  ## Примери

      # От supplier invoice (покупка):
      iex> save_bank_account_from_invoice(supplier_contact_id, "BG80BNBG96611020345678", tenant_id)
      {:ok, %ContactBankAccount{times_seen: 1, is_primary: true}}

      # Втори път същия IBAN:
      iex> save_bank_account_from_invoice(supplier_contact_id, "BG80BNBG96611020345678", tenant_id)
      {:ok, %ContactBankAccount{times_seen: 2}}

      # При bank_transaction (ИЗХОДЯЩО плащане):
      iex> find_contact_by_iban("BG80BNBG96611020345678", tenant_id)
      %Contact{name: "ИНФОРМЕЙТ ЕООД", is_supplier: true, ...}
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.Contacts.{Contact, ContactBankAccount}

  @doc """
  Записва или актуализира банкова сметка на контрагент от фактура.

  Ако сметката вече съществува за този контрагент:
  - Увеличава times_seen
  - Обновява last_seen_at

  Ако е първа сметка на контрагента:
  - Задава is_primary = true

  ## Parameters

    - contact_id: ID на контрагента
    - iban: IBAN номер (ще бъде нормализиран)
    - tenant_id: ID на организацията
    - opts: Опции
      - :bic - BIC код
      - :bank_name - Име на банка
      - :account_number - Номер на сметка (ако няма IBAN)
      - :user_id - ID на потребителя

  ## Examples

      iex> save_bank_account_from_invoice(123, "BG80BNBG96611020345678", 1)
      {:ok, %ContactBankAccount{}}

      iex> save_bank_account_from_invoice(123, "BG80BNBG96611020345678", 1, bic: "BNBGBGSD")
      {:ok, %ContactBankAccount{}}
  """
  def save_bank_account_from_invoice(contact_id, iban, tenant_id, opts \\ []) do
    iban = normalize_iban(iban)

    case get_existing_bank_account(contact_id, iban, tenant_id) do
      nil ->
        # Проверяваме дали е първа сметка на контрагента
        is_primary = is_first_account_for_contact?(contact_id, tenant_id)

        %ContactBankAccount{}
        |> ContactBankAccount.changeset(%{
          tenant_id: tenant_id,
          contact_id: contact_id,
          iban: iban,
          bic: Keyword.get(opts, :bic),
          bank_name: Keyword.get(opts, :bank_name),
          account_number: Keyword.get(opts, :account_number),
          currency: Keyword.get(opts, :currency, "BGN"),
          is_primary: is_primary,
          times_seen: 1,
          created_by_id: Keyword.get(opts, :user_id)
        })
        |> Repo.insert()

      existing ->
        # Актуализираме съществуваща сметка
        existing
        |> ContactBankAccount.changeset(%{
          times_seen: existing.times_seen + 1,
          last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second),
          # Актуализираме BIC и bank_name, ако са предоставени
          bic: Keyword.get(opts, :bic) || existing.bic,
          bank_name: Keyword.get(opts, :bank_name) || existing.bank_name
        })
        |> Repo.update()
    end
  end

  @doc """
  Намира контрагент по IBAN.

  Използва се при импорт на bank_transaction с correspondent_account.

  ## Examples

      iex> find_contact_by_iban("BG80BNBG96611020345678", 1)
      %Contact{name: "ИНФОРМЕЙТ ЕООД"}

      iex> find_contact_by_iban("BG99INVALID", 1)
      nil
  """
  def find_contact_by_iban(iban, tenant_id) when is_binary(iban) do
    iban = normalize_iban(iban)

    from(ba in ContactBankAccount,
      join: c in Contact,
      on: ba.contact_id == c.id,
      where: ba.tenant_id == ^tenant_id and ba.iban == ^iban,
      select: c,
      limit: 1
    )
    |> Repo.one()
  end

  def find_contact_by_iban(_, _), do: nil

  @doc """
  Намира контрагент по номер на сметка (за non-IBAN accounts).

  ## Examples

      iex> find_contact_by_account_number("1234567890", 1)
      %Contact{name: "Local Bank Account Ltd"}
  """
  def find_contact_by_account_number(account_number, tenant_id) when is_binary(account_number) do
    from(ba in ContactBankAccount,
      join: c in Contact,
      on: ba.contact_id == c.id,
      where: ba.tenant_id == ^tenant_id and ba.account_number == ^account_number,
      select: c,
      limit: 1
    )
    |> Repo.one()
  end

  def find_contact_by_account_number(_, _), do: nil

  @doc """
  Връща всички банкови сметки на контрагент.

  ## Examples

      iex> list_bank_accounts_for_contact(123, 1)
      [
        %ContactBankAccount{iban: "BG80...", is_primary: true, times_seen: 15},
        %ContactBankAccount{iban: "BG45...", is_primary: false, times_seen: 3}
      ]
  """
  def list_bank_accounts_for_contact(contact_id, tenant_id) do
    from(ba in ContactBankAccount,
      where: ba.contact_id == ^contact_id and ba.tenant_id == ^tenant_id,
      order_by: [desc: ba.is_primary, desc: ba.times_seen, desc: ba.last_seen_at]
    )
    |> Repo.all()
  end

  @doc """
  Връща главната банкова сметка на контрагент.

  Ако няма маркирана като primary, връща най-често използваната.

  ## Examples

      iex> get_primary_bank_account(123, 1)
      %ContactBankAccount{iban: "BG80...", is_primary: true}
  """
  def get_primary_bank_account(contact_id, tenant_id) do
    from(ba in ContactBankAccount,
      where: ba.contact_id == ^contact_id and ba.tenant_id == ^tenant_id,
      order_by: [desc: ba.is_primary, desc: ba.times_seen, desc: ba.last_seen_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Маркира сметка като главна (primary).

  Автоматично премахва is_primary от другите сметки на контрагента.

  ## Examples

      iex> set_as_primary(bank_account_id, contact_id, tenant_id)
      {:ok, %ContactBankAccount{is_primary: true}}
  """
  def set_as_primary(bank_account_id, contact_id, tenant_id) do
    Repo.transaction(fn ->
      # Премахваме is_primary от всички сметки на контрагента
      from(ba in ContactBankAccount,
        where: ba.contact_id == ^contact_id and ba.tenant_id == ^tenant_id
      )
      |> Repo.update_all(set: [is_primary: false])

      # Задаваме is_primary на избраната сметка
      bank_account = Repo.get!(ContactBankAccount, bank_account_id)

      bank_account
      |> ContactBankAccount.changeset(%{is_primary: true})
      |> Repo.update!()
    end)
  end

  @doc """
  Верифицира банкова сметка (например след успешно плащане).

  ## Examples

      iex> verify_bank_account(bank_account_id)
      {:ok, %ContactBankAccount{is_verified: true}}
  """
  def verify_bank_account(bank_account_id) do
    bank_account = Repo.get!(ContactBankAccount, bank_account_id)

    bank_account
    |> ContactBankAccount.changeset(%{is_verified: true})
    |> Repo.update()
  end

  @doc """
  Изтрива банкова сметка.

  ## Examples

      iex> delete_bank_account(bank_account_id)
      {:ok, %ContactBankAccount{}}
  """
  def delete_bank_account(bank_account_id) do
    bank_account = Repo.get!(ContactBankAccount, bank_account_id)
    Repo.delete(bank_account)
  end

  # Private functions

  defp get_existing_bank_account(contact_id, iban, tenant_id) when is_binary(iban) do
    from(ba in ContactBankAccount,
      where:
        ba.contact_id == ^contact_id and
          ba.iban == ^iban and
          ba.tenant_id == ^tenant_id
    )
    |> Repo.one()
  end

  defp get_existing_bank_account(_, _, _), do: nil

  defp is_first_account_for_contact?(contact_id, tenant_id) do
    count =
      from(ba in ContactBankAccount,
        where: ba.contact_id == ^contact_id and ba.tenant_id == ^tenant_id,
        select: count(ba.id)
      )
      |> Repo.one()

    count == 0
  end

  defp normalize_iban(nil), do: nil
  defp normalize_iban(""), do: nil

  defp normalize_iban(iban) when is_binary(iban) do
    iban
    |> String.replace(~r/\s/, "")
    |> String.upcase()
  end
end
