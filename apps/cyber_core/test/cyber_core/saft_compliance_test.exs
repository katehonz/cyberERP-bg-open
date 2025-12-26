defmodule CyberCore.SAFT.ComplianceTest do
  use CyberCore.DataCase

  alias CyberCore.Repo
  alias CyberCore.SAFT

  describe "SAF-T Compliance" do
    test "generates a valid monthly SAF-T file" do
      tenant = insert_tenant()
      insert_account(tenant)
      insert_customer(tenant)
      insert_supplier(tenant)
      insert_product(tenant)

      {:ok, xml} = SAFT.generate(:monthly, tenant.id, year: 2025, month: 1)
      assert SAFT.validate_xml(xml) == {:ok, :valid}
    end
  end

  defp insert_tenant do
    %CyberCore.Accounts.Tenant{}
    |> CyberCore.Accounts.Tenant.changeset(%{
      name: "Тестова фирма",
      slug: "test-tenant-#{System.unique_integer()}"
    })
    |> Repo.insert!()
  end

  defp insert_account(tenant) do
    {:ok, _account} =
      CyberCore.Accounting.create_account(tenant.id, %{
        code: "411",
        name: "Клиенти",
        account_type: :asset,
        account_class: 4
      })

    {:ok, _account} =
      CyberCore.Accounting.create_account(tenant.id, %{
        code: "401",
        name: "Доставчици",
        account_type: :liability,
        account_class: 4
      })
  end

  defp insert_customer(tenant) do
    {:ok, _contact} =
      CyberCore.Contacts.create_contact(%{
        tenant_id: tenant.id,
        name: "Тестов клиент",
        is_customer: true,
        registration_number: "123456789"
      })
  end

  defp insert_supplier(tenant) do
    {:ok, _contact} =
      CyberCore.Contacts.create_contact(%{
        tenant_id: tenant.id,
        name: "Тестов доставчик",
        is_supplier: true,
        registration_number: "987654321"
      })
  end

  defp insert_product(tenant) do
    {:ok, _product} =
      CyberCore.Inventory.create_product(%{
        tenant_id: tenant.id,
        name: "Тестов продукт",
        sku: "TP-001",
        category: "goods"
      })
  end
end
