defmodule CyberWeb.InvoiceController do
  use CyberWeb, :controller

  alias CyberCore.Sales
  alias CyberCore.Sales.Invoice

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък с фактури за текущия tenant.
  Поддържа филтриране по статус, тип, контакт, дати и търсене.

  ## Примери

      GET /api/invoices
      GET /api/invoices?status=issued
      GET /api/invoices?contact_id=1
      GET /api/invoices?from=2025-01-01&to=2025-12-31
      GET /api/invoices?search=INV-2025
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    invoices = Sales.list_invoices(tenant_id, opts)
    render(conn, :index, invoices: invoices)
  end

  @doc """
  Създаване на нова фактура с редове.

  ## Примери

      POST /api/invoices
      {
        "invoice": {
          "contact_id": 1,
          "invoice_no": "INV-2025-002",
          "issue_date": "2025-10-11",
          "billing_name": "Клиент ООД"
        },
        "lines": [
          {
            "product_id": 1,
            "description": "Продукт 1",
            "quantity": "10.00",
            "unit_price": "50.00",
            "tax_rate": "20.00"
          }
        ]
      }
  """
  def create(conn, %{"invoice" => invoice_params} = params) do
    tenant_id = conn.assigns.tenant_id
    invoice_attrs = Map.put(invoice_params, "tenant_id", tenant_id)
    lines_attrs = Map.get(params, "lines", [])

    with {:ok, %Invoice{} = invoice} <-
           Sales.create_invoice_with_lines(invoice_attrs, lines_attrs) do
      # Презареждаме с редовете
      invoice = Sales.get_invoice!(tenant_id, invoice.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/invoices/#{invoice}")
      |> render(:show, invoice: invoice)
    end
  end

  @doc """
  Извличане на една фактура по ID (с редовете).
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    invoice = Sales.get_invoice!(tenant_id, id)
    render(conn, :show, invoice: invoice)
  end

  @doc """
  Актуализиране на фактура (без редовете).
  За редовете използвайте отделен endpoint.
  """
  def update(conn, %{"id" => id, "invoice" => invoice_params}) do
    tenant_id = conn.assigns.tenant_id
    invoice = Sales.get_invoice!(tenant_id, id)

    with {:ok, %Invoice{} = invoice} <- Sales.update_invoice(invoice, invoice_params) do
      invoice = Sales.get_invoice!(tenant_id, invoice.id)
      render(conn, :show, invoice: invoice)
    end
  end

  @doc """
  Изтриване на фактура.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    invoice = Sales.get_invoice!(tenant_id, id)

    with {:ok, %Invoice{}} <- Sales.delete_invoice(invoice) do
      send_resp(conn, :no_content, "")
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:invoice_type, params["invoice_type"])
    |> maybe_add_filter(:contact_id, params["contact_id"])
    |> maybe_add_filter(:from, params["from"])
    |> maybe_add_filter(:to, params["to"])
    |> maybe_add_filter(:search, params["search"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, key, value)
       when key in [:status, :invoice_type, :from, :to, :search] do
    [{key, value} | opts]
  end

  defp maybe_add_filter(opts, :contact_id, value) do
    case Integer.parse(value) do
      {id, ""} -> [{:contact_id, id} | opts]
      _ -> opts
    end
  end

  defp maybe_add_filter(opts, _key, _value), do: opts
end
