defmodule CyberCore.DocumentProcessing.ProductMapper do
  @moduledoc """
  Smart product mapping service based on contact-specific nomenclature.

  This module handles the intelligent mapping of vendor product descriptions
  to our internal products. Each supplier/contact has their own way of describing
  products, and this service learns from previous mappings.

  ## Key Features

  - **Contact-specific mapping**: Each contact can have their own nomenclature
  - **Learning system**: Confidence increases with repeated usage (50% → 95%)
  - **Auto-selection**: Automatically selects product when confidence >= 80%
  - **Fuzzy suggestions**: Suggests products from similar descriptions from other contacts
  - **First-time mapping**: Provides suggestions based on ILIKE queries

  ## Confidence Levels

  - 1-2 times used: 50% confidence
  - 3-5 times: 70% confidence
  - 6-10 times: 85% confidence
  - 11+ times: 95% confidence

  Auto-select happens at 80%+ confidence (6+ times used).
  """

  import Ecto.Query
  alias CyberCore.Repo
  alias CyberCore.DocumentProcessing.ContactProductMapping
  alias CyberCore.Inventory.Product
  alias Decimal, as: D

  @doc """
  Suggests a product for a given contact and vendor description.

  Returns a map with:
  - `product`: The mapped product (nil if first time)
  - `confidence`: Confidence level (0-100)
  - `auto_select`: Boolean indicating if product should be auto-selected
  - `suggestions`: List of suggested products (for first-time or low confidence)

  ## Examples

      # First time mapping
      iex> suggest_product(contact_id, "Счетоводни услуги", tenant_id)
      %{
        product: nil,
        confidence: 0,
        auto_select: false,
        suggestions: [%{product: #Product<...>, reason: "Similar to 'Accounting services' used by ABC Ltd"}]
      }

      # Existing mapping with high confidence
      iex> suggest_product(contact_id, "Счетоводни услуги", tenant_id)
      %{
        product: #Product<123>,
        confidence: 85.0,
        auto_select: true,
        suggestions: []
      }
  """
  def suggest_product(contact_id, vendor_description, tenant_id) do
    trimmed_description = String.trim(vendor_description)

    case get_existing_mapping(contact_id, trimmed_description, tenant_id) do
      nil ->
        # First time - no mapping exists
        suggestions = fuzzy_suggest_from_other_contacts(trimmed_description, tenant_id)

        %{
          product: nil,
          confidence: D.new(0),
          auto_select: false,
          suggestions: suggestions,
          mapping_id: nil
        }

      mapping ->
        # Has existing mapping - calculate confidence
        product = Repo.get!(Product, mapping.product_id) |> Repo.preload(:measurement_unit)
        confidence = calculate_confidence(mapping.times_used)
        auto_select = D.compare(confidence, D.new(80)) != :lt

        %{
          product: product,
          confidence: confidence,
          auto_select: auto_select,
          suggestions: [],
          mapping_id: mapping.id
        }
    end
  end

  @doc """
  Suggests multiple products for a batch of line items from the same contact.

  Returns a list of suggestion maps, one for each line item.

  ## Example

      iex> suggest_products_batch(contact_id, [
      ...>   %{description: "Счетоводни услуги", quantity: 1},
      ...>   %{description: "Консултация", quantity: 2}
      ...> ], tenant_id)
      [
        %{description: "Счетоводни услуги", product: #Product<123>, confidence: 85.0, auto_select: true},
        %{description: "Консултация", product: nil, confidence: 0, auto_select: false, suggestions: [...]}
      ]
  """
  def suggest_products_batch(contact_id, line_items, tenant_id) do
    Enum.map(line_items, fn item ->
      suggestion = suggest_product(contact_id, item.description, tenant_id)

      Map.merge(item, suggestion)
    end)
  end

  @doc """
  Saves or updates a product mapping for a contact.

  If mapping exists, increments `times_used` and updates confidence.
  If new, creates mapping with initial confidence of 50%.

  ## Examples

      iex> save_product_mapping(contact_id, "Счетоводни услуги", product_id, tenant_id)
      {:ok, %ContactProductMapping{...}}
  """
  def save_product_mapping(contact_id, vendor_description, product_id, tenant_id, user_id \\ nil) do
    trimmed_description = String.trim(vendor_description)

    case get_existing_mapping(contact_id, trimmed_description, tenant_id) do
      nil ->
        # Create new mapping
        %ContactProductMapping{}
        |> ContactProductMapping.changeset(%{
          tenant_id: tenant_id,
          contact_id: contact_id,
          vendor_description: trimmed_description,
          product_id: product_id,
          times_used: 1,
          confidence: D.new("50.0"),
          created_by_id: user_id,
          last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert()

      mapping ->
        # Update existing mapping
        new_times_used = mapping.times_used + 1
        new_confidence = calculate_confidence(new_times_used)

        mapping
        |> ContactProductMapping.changeset(%{
          times_used: new_times_used,
          confidence: new_confidence,
          last_used_at: DateTime.utc_now() |> DateTime.truncate(:second),
          # Allow changing the mapped product
          product_id: product_id
        })
        |> Repo.update()
    end
  end

  @doc """
  Saves mappings for all line items in an invoice.

  This is typically called after user approves the mappings.

  ## Example

      iex> save_invoice_mappings(contact_id, [
      ...>   %{description: "Услуга 1", product_id: 123},
      ...>   %{description: "Услуга 2", product_id: 456}
      ...> ], tenant_id, user_id)
      {:ok, [%ContactProductMapping{...}, %ContactProductMapping{...}]}
  """
  def save_invoice_mappings(contact_id, line_items, tenant_id, user_id \\ nil) do
    results =
      Enum.map(line_items, fn item ->
        save_product_mapping(
          contact_id,
          item.description,
          item.product_id,
          tenant_id,
          user_id
        )
      end)

    # Check if all succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, mapping} -> mapping end)}
    else
      errors = Enum.filter(results, &match?({:error, _}, &1))
      {:error, errors}
    end
  end

  @doc """
  Gets all mappings for a specific contact.

  Useful for reviewing/managing a supplier's nomenclature mappings.
  """
  def list_mappings_for_contact(contact_id, tenant_id) do
    from(m in ContactProductMapping,
      where: m.contact_id == ^contact_id and m.tenant_id == ^tenant_id,
      order_by: [desc: m.last_used_at],
      preload: [:product]
    )
    |> Repo.all()
  end

  @doc """
  Gets all mappings for a specific product.

  Shows how different contacts refer to this product.
  """
  def list_mappings_for_product(product_id, tenant_id) do
    from(m in ContactProductMapping,
      where: m.product_id == ^product_id and m.tenant_id == ^tenant_id,
      order_by: [desc: m.times_used],
      preload: [:contact]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a specific mapping.

  Useful when a mapping was incorrect and needs to be recreated.
  """
  def delete_mapping(mapping_id) do
    case Repo.get(ContactProductMapping, mapping_id) do
      nil -> {:error, :not_found}
      mapping -> Repo.delete(mapping)
    end
  end

  # Private functions

  defp get_existing_mapping(contact_id, vendor_description, tenant_id) do
    from(m in ContactProductMapping,
      where:
        m.contact_id == ^contact_id and
          m.vendor_description == ^vendor_description and
          m.tenant_id == ^tenant_id
    )
    |> Repo.one()
  end

  defp fuzzy_suggest_from_other_contacts(description, tenant_id) do
    # Search for similar descriptions from OTHER contacts
    # Using ILIKE for case-insensitive pattern matching
    search_pattern = "%#{description}%"

    similar_mappings =
      from(m in ContactProductMapping,
        where:
          m.tenant_id == ^tenant_id and
            ilike(m.vendor_description, ^search_pattern),
        order_by: [desc: m.times_used, desc: m.confidence],
        limit: 10,
        preload: [:product, :contact]
      )
      |> Repo.all()

    # Also try partial word matches
    words = String.split(description, ~r/\s+/) |> Enum.filter(&(String.length(&1) > 3))

    word_matches =
      if Enum.any?(words) do
        word_queries =
          Enum.map(words, fn word ->
            word_pattern = "%#{word}%"

            from(m in ContactProductMapping,
              where:
                m.tenant_id == ^tenant_id and
                  ilike(m.vendor_description, ^word_pattern)
            )
          end)

        # Union all word queries
        base_query = Enum.at(word_queries, 0)

        Enum.reduce(Enum.drop(word_queries, 1), base_query, fn query, acc ->
          union(acc, ^query)
        end)
        |> subquery()
        |> then(fn subq ->
          from(m in ContactProductMapping,
            join: s in subquery(subq),
            on: m.id == s.id,
            order_by: [desc: m.times_used],
            limit: 5,
            preload: [:product, :contact]
          )
        end)
        |> Repo.all()
      else
        []
      end

    # Combine and deduplicate
    all_matches = (similar_mappings ++ word_matches) |> Enum.uniq_by(& &1.product_id)

    # Format as suggestions
    Enum.map(all_matches, fn mapping ->
      %{
        product: mapping.product,
        reason: "Similar to '#{mapping.vendor_description}' used by #{mapping.contact.name}",
        confidence: mapping.confidence,
        times_used: mapping.times_used
      }
    end)
    # Limit to top 5 suggestions
    |> Enum.take(5)
  end

  defp calculate_confidence(times_used) do
    cond do
      times_used <= 0 -> D.new("0.0")
      times_used <= 2 -> D.new("50.0")
      times_used <= 5 -> D.new("70.0")
      times_used <= 10 -> D.new("85.0")
      true -> D.new("95.0")
    end
  end
end
