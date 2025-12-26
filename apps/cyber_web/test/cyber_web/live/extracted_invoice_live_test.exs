defmodule CyberWeb.ExtractedInvoiceLiveTest do
  use CyberWeb.ConnCase

  import Phoenix.LiveViewTest
  import Cyber.Fixtures

  @moduletag :capture_log

  describe "Index" do
    setup do
      tenant = tenant_fixture()
      user = user_fixture(tenant_id: tenant.id)
      invoice = extracted_invoice_fixture(tenant_id: tenant.id)

      conn =
        Plug.Test.init_test_session(build_conn(), %{
          "user_id" => user.id,
          "tenant_id" => tenant.id
        })

      {:ok, conn: conn, user: user, tenant: tenant, invoice: invoice}
    end

    test "loads the index page and shows the invoice", %{conn: conn, invoice: invoice} do
      {:ok, view, _html} = live(conn, ~p"/extracted-invoices")

      assert has_element?(view, "h1", "Сканирани Документи")
      assert has_element?(view, "table")
      assert has_element?(view, "td", invoice.invoice_number)
    end

    test "opens the modal when an invoice is clicked", %{conn: conn, invoice: invoice} do
      {:ok, view, _html} = live(conn, ~p"/extracted-invoices")

      view
      |> element("tr[phx-value-id='#{invoice.id}']")
      |> render_click()

      assert has_element?(view, "#invoice-modal")
    end

    test "navigates between invoices in the modal", %{conn: conn, tenant: tenant} do
      # Create 3 invoices - list is sorted desc by inserted_at so newest is first
      _invoice1 = extracted_invoice_fixture(tenant_id: tenant.id)
      Process.sleep(10)
      _invoice2 = extracted_invoice_fixture(tenant_id: tenant.id)
      Process.sleep(10)
      _invoice3 = extracted_invoice_fixture(tenant_id: tenant.id)

      {:ok, view, html} = live(conn, ~p"/extracted-invoices")

      # Count the invoice rows in the rendered HTML
      row_count = html |> String.split("phx-click=\"open_invoice\"") |> length() |> Kernel.-(1)
      assert row_count >= 3, "Expected at least 3 invoices, got #{row_count}"

      # Click on first invoice row (index 0)
      first_row = view |> element("tbody tr:first-child")
      first_row |> render_click()

      assert has_element?(view, "#invoice-modal")

      # Click next (should navigate to index 1)
      view
      |> element("#invoice-modal button[phx-click=next_invoice]")
      |> render_click()

      assert has_element?(view, "#invoice-modal")

      # Click previous (should navigate back to index 0)
      view
      |> element("#invoice-modal button[phx-click=previous_invoice]")
      |> render_click()

      assert has_element?(view, "#invoice-modal")
    end

    test "selects and deselects all invoices", %{conn: conn, tenant: tenant} do
      extracted_invoice_fixture(tenant_id: tenant.id)

      {:ok, view, _html} = live(conn, ~p"/extracted-invoices")

      view
      |> element("input[type=checkbox][phx-click=toggle_select_all]")
      |> render_click()

      assert has_element?(view, "p", "Избрани: 2")

      view
      |> element("input[type=checkbox][phx-click=toggle_select_all]")
      |> render_click()

      refute has_element?(view, "p", "Избрани: 2")
    end

    test "deletes selected invoices", %{conn: conn, invoice: invoice} do
      invoice2 = extracted_invoice_fixture(tenant_id: invoice.tenant_id, invoice_number: "456")

      {:ok, view, _html} = live(conn, ~p"/extracted-invoices")

      view
      |> element("input[type=checkbox][phx-value-id='#{invoice.id}']")
      |> render_click()

      view
      |> element("input[type=checkbox][phx-value-id='#{invoice2.id}']")
      |> render_click()

      view
      |> element("button[phx-click=bulk_delete]")
      |> render_click()

      refute has_element?(view, "td", invoice.invoice_number)
      refute has_element?(view, "td", "456")
    end
  end
end
