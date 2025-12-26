defmodule CyberCore.InventoryTest do
  use CyberCore.DataCase

  alias CyberCore.Inventory
  alias CyberCore.Accounting
  alias CyberCore.Accounts

  describe "opening balances" do
    test "sets opening balance for product in warehouse" do
      # Създаване на tenant
      {:ok, tenant} = Accounts.create_tenant(%{
        name: "Тестова фирма",
        slug: "test-#{System.unique_integer([:positive])}"
      })
      tenant_id = tenant.id

      # Създаване на сметки необходими за journal entries
      {:ok, _inv_account} = Accounting.create_account(tenant_id, %{
        code: "302",
        name: "Материали",
        account_type: "asset",
        account_class: 3
      })

      {:ok, _equity_account} = Accounting.create_account(tenant_id, %{
        code: "801",
        name: "Уставен капитал",
        account_type: "equity",
        account_class: 1
      })

      # Създаване на тестови данни
      {:ok, product} = Inventory.create_product(%{
        tenant_id: tenant_id,
        name: "Тестов продукт",
        sku: "PROD-001",
        unit: "бр.",
        category: "goods"
      })

      {:ok, warehouse} = Inventory.create_warehouse(%{
        tenant_id: tenant_id,
        code: "WH-001",
        name: "Тестов склад"
      })

      # Задаване на начално салдо
      quantity = Decimal.new("100")
      cost = Decimal.new("2.50")

      _result = Inventory.set_opening_balance(tenant_id, product.id, warehouse.id, quantity, cost)

      # Проверка дали началното салдо е записано в продукта
      updated_product = Inventory.get_product!(tenant_id, product.id)
      assert Decimal.eq?(updated_product.opening_quantity, quantity)
      assert Decimal.eq?(updated_product.opening_cost, cost)
    end
  end

  describe "account opening balances" do
    test "sets opening balance for account" do
      # Създаване на tenant
      {:ok, tenant} = Accounts.create_tenant(%{
        name: "Тестова фирма 2",
        slug: "test2-#{System.unique_integer([:positive])}"
      })
      tenant_id = tenant.id

      # Създаване на капиталова сметка за баланс
      {:ok, _equity_account} = Accounting.create_account(tenant_id, %{
        code: "801",
        name: "Уставен капитал",
        account_type: "equity",
        account_class: 1
      })

      # Създаване на тестова сметка
      {:ok, account} = Accounting.create_account(tenant_id, %{
        code: "401",
        name: "Доставчици",
        account_type: "liability",
        account_class: 4
      })

      # Задаване на начално салдо
      balance = Decimal.new("10000")
      {:ok, updated_account} = Accounting.set_account_opening_balance(tenant_id, account.id, balance)

      # Проверка дали началното салдо е записано правилно
      assert Decimal.eq?(updated_account.opening_balance, balance)
    end
  end
end
