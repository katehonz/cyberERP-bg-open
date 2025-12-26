defmodule CyberCore.VatTest do
  use CyberCore.DataCase, async: true

  alias CyberCore.Vat
  alias CyberCore.Accounts

  setup do
    tenant_id = "123456789"
    {:ok, tenant} = Accounts.create_tenant(%{id: tenant_id, name: "Test Tenant", slug: tenant_id})
    %{tenant: tenant}
  end

  test "generate_vat_declaration/3", %{tenant: tenant} do
    year = 2025
    month = 10

    # Create some test data
    {:ok, contact} =
      CyberCore.Contacts.create_contact(%{
        tenant_id: tenant.id,
        name: "Test Contact",
        vat_number: "BG123456789"
      })

    {:ok, _invoice} =
      CyberCore.Sales.create_invoice(%{
        tenant_id: tenant.id,
        contact_id: contact.id,
        invoice_no: "123",
        issue_date: ~D[2025-10-15],
        subtotal: 100,
        tax_amount: 20,
        billing_name: "Test Contact",
        vat_document_type: "01"
      })

    {:ok, supplier} =
      CyberCore.Contacts.create_contact(%{
        tenant_id: tenant.id,
        name: "Test Supplier",
        vat_number: "BG987654321",
        is_supplier: true
      })

    {:ok, _supplier_invoice} =
      CyberCore.Purchase.create_supplier_invoice(%{
        tenant_id: tenant.id,
        supplier_id: supplier.id,
        supplier_invoice_no: "456",
        invoice_date: ~D[2025-10-20],
        subtotal: 50,
        tax_amount: 10,
        vat_document_type: "01",
        invoice_no: "456",
        supplier_name: "Test Supplier"
      })

    declaration = Vat.generate_vat_declaration(tenant.id, year, month)

    assert declaration["PRODAGBI.TXT"] != ""
    assert declaration["POKUPKI.TXT"] != ""
    assert declaration["DEKLAR.TXT"] != ""
  end
end
