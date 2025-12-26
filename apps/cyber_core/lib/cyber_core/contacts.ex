defmodule CyberCore.Contacts do
  @moduledoc """
  Контакти и CRM функционалност.
  """

  import Ecto.Query, warn: false

  alias CyberCore.Repo
  alias CyberCore.Contacts.Contact

  def list_contacts(tenant_id, opts \\ []) do
    query =
      from c in Contact,
        where: c.tenant_id == ^tenant_id,
        order_by: [asc: c.name]

    Repo.all(apply_contact_filters(query, opts))
  end

  def get_contact!(tenant_id, id) do
    Repo.get_by!(Contact, tenant_id: tenant_id, id: id)
  end

  @doc """
  Gets a contact by VAT number.

  Returns nil if not found.
  """
  def get_contact_by_vat(tenant_id, vat_number) when is_binary(vat_number) and vat_number != "" do
    Repo.get_by(Contact, tenant_id: tenant_id, vat_number: vat_number)
  end

  def get_contact_by_vat(_tenant_id, _), do: nil

  @doc """
  Searches contacts by name.

  Returns list of contacts matching the search term.
  """
  def search_contacts(tenant_id, search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    like_term = "%#{search_term}%"

    from(c in Contact,
      where: c.tenant_id == ^tenant_id,
      where:
        ilike(c.name, ^like_term) or
          ilike(c.company, ^like_term) or
          ilike(c.vat_number, ^like_term) or
          ilike(c.registration_number, ^like_term),
      order_by: [asc: c.name],
      limit: ^limit
    )
    |> Repo.all()
  end

  def create_contact(attrs) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  def delete_contact(%Contact{} = contact), do: Repo.delete(contact)

  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  defp apply_contact_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:is_company, value}, acc ->
        from c in acc, where: c.is_company == ^value

      {:search, term}, acc when is_binary(term) and term != "" ->
        like_term = "%#{term}%"

        from c in acc,
          where:
            ilike(c.name, ^like_term) or
              ilike(c.company, ^like_term) or
              ilike(c.email, ^like_term)

      _, acc ->
        acc
    end)
  end
end
