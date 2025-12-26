defmodule CyberWeb.Accounting.JournalEntryController do
  use CyberWeb, :controller

  alias CyberCore.Accounting
  alias CyberCore.Accounting.{JournalEntry, JournalLine}

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    filters = build_filters(params)

    entries = Accounting.list_journal_entries(tenant.id, filters)
    json(conn, %{data: Enum.map(entries, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      entry = Accounting.get_journal_entry!(tenant.id, id, [:lines])
      json(conn, %{data: serialize_with_lines(entry)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant

    entry_attrs =
      params
      |> Map.get("journal_entry", params)
      |> Map.put("tenant_id", tenant.id)
      |> Map.drop(["id", "inserted_at", "updated_at", "lines"])

    lines_attrs = Map.get(params, "lines", [])

    with {:ok, %JournalEntry{} = entry} <-
           Accounting.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize_with_lines(entry)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %JournalEntry{} = entry <- Accounting.get_journal_entry!(tenant.id, id),
         {:ok, %JournalEntry{} = updated} <-
           Accounting.update_journal_entry(entry, payload(params)) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %JournalEntry{} = entry <- Accounting.get_journal_entry!(tenant.id, id),
         {:ok, _entry} <- Accounting.delete_journal_entry(entry) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("journal_entry", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id", "lines"])
  end

  defp build_filters(params) do
    []
    |> maybe_put(:status, params["status"])
    |> maybe_put(:source, params["source"])
    |> maybe_put(:from, params["from"])
    |> maybe_put(:to, params["to"])
    |> maybe_put(:search, params["search"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp serialize(%JournalEntry{} = entry) do
    %{
      id: entry.id,
      entry_number: entry.entry_number,
      document_date: entry.document_date,
      accounting_date: entry.accounting_date,
      description: entry.description,
      is_posted: entry.is_posted,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp serialize_with_lines(%JournalEntry{} = entry) do
    entry
    |> serialize()
    |> Map.put(:lines, Enum.map(entry.lines || [], &serialize_line/1))
  end

  defp serialize_line(%JournalLine{} = line) do
    %{
      id: line.id,
      account_id: line.account_id,
      description: line.description,
      debit: line.debit,
      credit: line.credit,
      currency: line.currency
    }
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> {:ok, int}
      :error -> {:error, :not_found}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: {:error, :not_found}
end
