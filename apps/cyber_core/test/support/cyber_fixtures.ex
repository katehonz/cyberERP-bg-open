defmodule Cyber.Fixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cyber` application.
  """

  alias CyberCore.Accounts
  alias CyberCore.DocumentProcessing
  alias Decimal

  def tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} =
      attrs
      |> Enum.into(%{
        name: "Test Tenant",
        slug: "test-tenant-" <> Integer.to_string(System.unique_integer())
      })
      |> Accounts.create_tenant()

    tenant
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user" <> Integer.to_string(System.unique_integer()) <> "@example.com",
        password: "password123",
        password_confirmation: "password123"
      })
      |> Accounts.register_user()

    user
  end

  def document_upload_fixture(attrs \\ %{}) do
    tenant_id = attrs[:tenant_id] || tenant_fixture().id
    user_id = attrs[:user_id] || user_fixture(tenant_id: tenant_id).id

    {:ok, document_upload} =
      attrs
      |> Enum.into(%{
        tenant_id: tenant_id,
        user_id: user_id,
        original_filename: "test.pdf",
        stored_filename: "test.pdf",
        status: "completed"
      })
      |> DocumentProcessing.create_document_upload()

    document_upload
  end

  def extracted_invoice_fixture(attrs \\ %{}) do
    tenant_id = attrs[:tenant_id] || tenant_fixture().id

    document_upload_id =
      attrs[:document_upload_id] || document_upload_fixture(tenant_id: tenant_id).id

    {:ok, extracted_invoice} =
      attrs
      |> Enum.into(%{
        tenant_id: tenant_id,
        document_upload_id: document_upload_id,
        invoice_number: "INV-" <> Integer.to_string(System.unique_integer()),
        invoice_type: "purchase",
        vendor_name: "Test Vendor",
        total_amount: Decimal.new("123.45"),
        currency: "BGN",
        status: "pending_review",
        line_items: [
          %{
            "description" => "Test item",
            "quantity" => "1",
            "unit_price" => "100",
            "total" => "123.45"
          }
        ]
      })
      |> DocumentProcessing.create_extracted_invoice()

    extracted_invoice
  end
end
