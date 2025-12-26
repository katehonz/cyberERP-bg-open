defmodule CyberWeb.QuotationController do
  use CyberWeb, :controller

  alias CyberCore.Sales
  alias CyberCore.Sales.Quotation

  action_fallback CyberWeb.FallbackController

  @doc """
  Извличане на списък с оферти за текущия tenant.
  Поддържа филтриране по статус, контакт, дати и търсене.

  ## Примери

      GET /api/quotations
      GET /api/quotations?status=sent
      GET /api/quotations?contact_id=1
      GET /api/quotations?from=2025-01-01&to=2025-12-31
      GET /api/quotations?search=QUO-2025
  """
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = build_filter_opts(params)
    quotations = Sales.list_quotations(tenant_id, opts)
    render(conn, :index, quotations: quotations)
  end

  @doc """
  Създаване на нова оферта с редове.

  ## Примери

      POST /api/quotations
      {
        "quotation": {
          "contact_id": 1,
          "quotation_no": "QUO-2025-002",
          "issue_date": "2025-10-11",
          "valid_until": "2025-11-11",
          "contact_name": "Клиент ООД"
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
  def create(conn, %{"quotation" => quotation_params} = params) do
    tenant_id = conn.assigns.tenant_id
    quotation_attrs = Map.put(quotation_params, "tenant_id", tenant_id)
    lines_attrs = Map.get(params, "lines", [])

    with {:ok, %Quotation{} = quotation} <-
           Sales.create_quotation_with_lines(quotation_attrs, lines_attrs) do
      # Презареждаме с редовете
      quotation = Sales.get_quotation!(tenant_id, quotation.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/quotations/#{quotation}")
      |> render(:show, quotation: quotation)
    end
  end

  @doc """
  Извличане на една оферта по ID (с редовете).
  """
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    quotation = Sales.get_quotation!(tenant_id, id)
    render(conn, :show, quotation: quotation)
  end

  @doc """
  Актуализиране на оферта (без редовете).
  За редовете използвайте отделен endpoint.
  """
  def update(conn, %{"id" => id, "quotation" => quotation_params}) do
    tenant_id = conn.assigns.tenant_id
    quotation = Sales.get_quotation!(tenant_id, id)

    with {:ok, %Quotation{} = quotation} <- Sales.update_quotation(quotation, quotation_params) do
      quotation = Sales.get_quotation!(tenant_id, quotation.id)
      render(conn, :show, quotation: quotation)
    end
  end

  @doc """
  Изтриване на оферта.
  """
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    quotation = Sales.get_quotation!(tenant_id, id)

    with {:ok, %Quotation{}} <- Sales.delete_quotation(quotation) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Конвертиране на оферта във фактура.

  ## Примери

      POST /api/quotations/:id/convert
      {
        "invoice_no": "INV-2025-010",
        "issue_date": "2025-10-11"
      }
  """
  def convert(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    quotation = Sales.get_quotation!(tenant_id, id)

    with {:ok, invoice} <- Sales.convert_quotation_to_invoice(quotation) do
      conn
      |> put_status(:created)
      |> json(%{
        message: "Офертата беше успешно конвертирана във фактура",
        invoice_id: invoice.id,
        invoice_no: invoice.invoice_no
      })
    end
  end

  defp build_filter_opts(params) do
    []
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:contact_id, params["contact_id"])
    |> maybe_add_filter(:from, params["from"])
    |> maybe_add_filter(:to, params["to"])
    |> maybe_add_filter(:search, params["search"])
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts

  defp maybe_add_filter(opts, key, value) when key in [:status, :from, :to, :search] do
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
