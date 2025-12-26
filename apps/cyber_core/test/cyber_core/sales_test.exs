defmodule CyberCore.SalesTest do
  use CyberCore.DataCase

  alias CyberCore.Accounts.Tenant
  alias CyberCore.Contacts
  alias CyberCore.Inventory
  alias CyberCore.Repo
  alias CyberCore.Sales
  alias Decimal, as: D

  describe "create_sale_with_items/3" do
    test "persists sale, lines and totals" do
      tenant = insert_tenant()
      customer = insert_customer(tenant)
      product = insert_product(tenant)
      warehouse = insert_warehouse(tenant)

      sale_attrs = %{
        tenant_id: tenant.id,
        invoice_number: "POS-TEST",
        customer_id: customer.id,
        customer_name: customer.name,
        customer_email: customer.email,
        customer_phone: customer.phone,
        date: DateTime.utc_now(),
        amount: D.new("24.00"),
        status: "paid",
        warehouse_id: warehouse.id,
        payment_method: "cash",
        pos_reference: "POS-#{System.unique_integer([:positive])}"
      }

      line_attrs = [
        %{
          product_id: product.id,
          description: product.name,
          sku: product.sku,
          unit: product.unit,
          quantity: "2",
          unit_price: "10.00",
          discount_percent: "0",
          tax_rate: "20"
        }
      ]

      assert {:ok, sale} =
               Sales.create_sale_with_items(sale_attrs, line_attrs, create_stock_movements: false)

      assert D.eq?(sale.amount, D.new("24.00"))
      assert sale.status == "paid"
      assert length(sale.sale_items) == 1

      [item] = sale.sale_items
      assert D.eq?(item.quantity, D.new(2))
      assert D.eq?(item.unit_price, D.new("10.00"))
      assert D.eq?(item.total_amount, D.new("24.00"))
    end
  end

  defp insert_tenant do
    %Tenant{}
    |> Tenant.changeset(%{
      name: "Тестов клиент",
      slug: "tenant-#{System.unique_integer([:positive])}"
    })
    |> Repo.insert!()
  end

  defp insert_customer(tenant) do
    {:ok, contact} =
      Contacts.create_contact(%{
        tenant_id: tenant.id,
        name: "POS Клиент",
        email: "client@example.com",
        phone: "+359888123456",
        is_customer: true
      })

    contact
  end

  defp insert_product(tenant) do
    {:ok, product} =
      Inventory.create_product(%{
        tenant_id: tenant.id,
        name: "Тест продукт",
        sku: "SKU-#{System.unique_integer([:positive])}",
        category: "goods",
        quantity: 0,
        price: D.new("10.00"),
        unit: "бр."
      })

    product
  end

  defp insert_warehouse(tenant) do
    {:ok, warehouse} =
      Inventory.create_warehouse(%{
        tenant_id: tenant.id,
        code: "WH-#{System.unique_integer([:positive])}",
        name: "Основен склад"
      })

    warehouse
  end
end
