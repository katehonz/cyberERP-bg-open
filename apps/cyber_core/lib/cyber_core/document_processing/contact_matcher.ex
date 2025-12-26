defmodule CyberCore.DocumentProcessing.ContactMatcher do
  alias CyberCore.Contacts
  alias CyberCore.Contacts.Contact

  def find_or_create_contact(tenant_id, name, vat_number, address) do
    case Contacts.get_contact_by_vat(tenant_id, vat_number) do
      nil ->
        attrs = %{
          "tenant_id" => tenant_id,
          "name" => name,
          "vat_number" => vat_number,
          "address" => address,
          "is_supplier" => true,
          "is_company" => true
        }

        case Contacts.create_contact(attrs) do
          {:ok, contact} -> {:ok, contact}
          {:error, changeset} -> {:error, changeset}
        end

      contact ->
        {:ok, contact}
    end
  end
end
