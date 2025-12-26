# Примерни банкови сметки
alias CyberCore.Bank

# Проверка дали вече има банкови сметки за tenant 1
case Bank.list_bank_accounts(1) do
  [] ->
    IO.puts("Създаване на примерни банкови сметки...")

    # Основна BGN сметка
    {:ok, _} =
      Bank.create_bank_account(%{
        tenant_id: 1,
        account_no: "10200001234567",
        iban: "BG80BNBG96611020345678",
        bic: "BNBGBGSD",
        account_type: "current",
        currency: "BGN",
        bank_name: "Българска народна банка",
        bank_code: "BNBG",
        branch_name: "Централно управление",
        initial_balance: Decimal.new("10000.00"),
        current_balance: Decimal.new("10000.00"),
        is_active: true,
        notes: "Основна разплащателна сметка в BGN"
      })

    # EUR сметка
    {:ok, _} =
      Bank.create_bank_account(%{
        tenant_id: 1,
        account_no: "10200001234568",
        iban: "BG80BNBG96611020345679",
        bic: "BNBGBGSD",
        account_type: "foreign_currency",
        currency: "EUR",
        bank_name: "Българска народна банка",
        bank_code: "BNBG",
        branch_name: "Централно управление",
        initial_balance: Decimal.new("5000.00"),
        current_balance: Decimal.new("5000.00"),
        is_active: true,
        notes: "Валутна сметка в EUR"
      })

    # USD сметка
    {:ok, _} =
      Bank.create_bank_account(%{
        tenant_id: 1,
        account_no: "10200001234569",
        iban: "BG80BNBG96611020345680",
        bic: "BNBGBGSD",
        account_type: "foreign_currency",
        currency: "USD",
        bank_name: "Българска народна банка",
        bank_code: "BNBG",
        branch_name: "Централно управление",
        initial_balance: Decimal.new("3000.00"),
        current_balance: Decimal.new("3000.00"),
        is_active: true,
        notes: "Валутна сметка в USD"
      })

    # Спестовна сметка BGN
    {:ok, _} =
      Bank.create_bank_account(%{
        tenant_id: 1,
        account_no: "10300001234570",
        iban: "BG80BNBG96611030345681",
        bic: "BNBGBGSD",
        account_type: "savings",
        currency: "BGN",
        bank_name: "Българска народна банка",
        bank_code: "BNBG",
        branch_name: "Централно управление",
        initial_balance: Decimal.new("50000.00"),
        current_balance: Decimal.new("50000.00"),
        is_active: true,
        notes: "Спестовна сметка за резерви"
      })

    IO.puts("✓ Създадени 4 примерни банкови сметки")

  _existing ->
    IO.puts("⚠ Банкови сметки вече съществуват, пропускам създаването")
end
