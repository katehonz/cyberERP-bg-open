defmodule CyberWeb.ContactController do
  use CyberWeb, :controller

  alias CyberCore.Contacts
  alias CyberCore.Contacts.Contact

  action_fallback CyberWeb.FallbackController
  plug CyberWeb.Plugs.RequireAuth

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    filters = build_filters(params)

    contacts = Contacts.list_contacts(tenant.id, filters)
    json(conn, %{data: Enum.map(contacts, &serialize/1)})
  end

  def show(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id) do
      contact = Contacts.get_contact!(tenant.id, id)
      json(conn, %{data: serialize(contact)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, params) do
    tenant = conn.assigns.current_tenant

    attrs = params |> payload() |> Map.put("tenant_id", tenant.id)

    with {:ok, %Contact{} = contact} <- Contacts.create_contact(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(contact)})
    end
  end

  def update(conn, %{"id" => raw_id} = params) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Contact{} = contact <- Contacts.get_contact!(tenant.id, id),
         {:ok, %Contact{} = updated} <- Contacts.update_contact(contact, params |> payload()) do
      json(conn, %{data: serialize(updated)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => raw_id}) do
    tenant = conn.assigns.current_tenant

    with {:ok, id} <- parse_id(raw_id),
         %Contact{} = contact <- Contacts.get_contact!(tenant.id, id),
         {:ok, _contact} <- Contacts.delete_contact(contact) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp payload(params) do
    params
    |> Map.get("contact", params)
    |> Map.drop(["id", "inserted_at", "updated_at", "tenant_id"])
  end

  defp build_filters(params) do
    []
    |> maybe_put(:is_company, parse_bool(params["is_company"]))
    |> maybe_put(:search, params["search"])
  end

  defp maybe_put(filters, _key, nil), do: filters
  defp maybe_put(filters, _key, ""), do: filters
  defp maybe_put(filters, key, value), do: Keyword.put(filters, key, value)

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil

  defp serialize(%Contact{} = contact) do
    %{
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone: contact.phone,
      company: contact.company,
      address: contact.address,
      city: contact.city,
      country: contact.country,
      is_company: contact.is_company,
      accounting_account_id: contact.accounting_account_id,
      inserted_at: contact.inserted_at,
      updated_at: contact.updated_at
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
