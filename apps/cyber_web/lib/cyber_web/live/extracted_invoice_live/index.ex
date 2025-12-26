defmodule CyberWeb.ExtractedInvoiceLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Sales
  alias CyberCore.Purchase
  alias CyberCore.DocumentProcessing
  alias CyberCore.DocumentProcessing.ContactMatcher
  alias CyberCore.DocumentProcessing.ProductMapper
  alias CyberCore.Contacts.ContactBankAccountMapper
  alias CyberCore.Inventory
  alias CyberCore.Settings
  alias CyberCore.Accounting
  alias CyberCore.Repo

  @impl true
  def mount(_params, session, socket) do
    tenant_id = session["tenant_id"] || socket.assigns[:current_tenant_id] || 1
    user_id = session["user_id"] || socket.assigns[:current_user_id]
    {:ok, accounting_settings} = Settings.get_or_create_accounting_settings(tenant_id)

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:user_id, user_id)
      |> assign(:page_title, "Сканирани Документи")
      |> assign(:accounting_settings, accounting_settings)
      |> assign(:show_modal, false)
      |> assign(:show_product_modal, false)
      |> assign(:new_product_name, nil)
      |> assign(:product_form_line_index, nil)
      |> assign(:current_invoice, nil)
      |> assign(:current_index, 0)
      |> assign(:line_items_with_suggestions, [])
      |> assign(:search_query, "")
      |> assign(:product_search_results, [])
      |> assign(:bank_account_info, nil)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:contact_status, :not_loaded) # :found, :created, :error
      |> load_extracted_invoices()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("open_invoice", %{"id" => id}, socket) do
    invoice = DocumentProcessing.get_extracted_invoice!(socket.assigns.tenant_id, id)

    # Find the index in the list
    index =
      Enum.find_index(socket.assigns.extracted_invoices, fn inv -> inv.id == invoice.id end) || 0

    socket =
      socket
      |> assign(:current_invoice, invoice)
      |> assign(:current_index, index)
      |> assign(:show_modal, true)
      |> load_line_items_with_suggestions(invoice)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("next_invoice", _params, socket) do
    invoices = socket.assigns.extracted_invoices
    current_index = socket.assigns.current_index

    if current_index < length(invoices) - 1 do
      new_index = current_index + 1
      invoice = Enum.at(invoices, new_index)

      socket =
        socket
        |> assign(:current_invoice, invoice)
        |> assign(:current_index, new_index)
        |> load_line_items_with_suggestions(invoice)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("previous_invoice", _params, socket) do
    invoices = socket.assigns.extracted_invoices
    current_index = socket.assigns.current_index

    if current_index > 0 do
      new_index = current_index - 1
      invoice = Enum.at(invoices, new_index)

      socket =
        socket
        |> assign(:current_invoice, invoice)
        |> assign(:current_index, new_index)
        |> load_line_items_with_suggestions(invoice)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_line_item",
        %{"index" => index_str, "field" => field, "value" => value},
        socket
      ) do
    index = String.to_integer(index_str)
    line_items = socket.assigns.line_items_with_suggestions

    updated_line =
      line_items
      |> Enum.at(index)
      |> update_line_field(field, value)

    updated_items = List.replace_at(line_items, index, updated_line)

    {:noreply, assign(socket, :line_items_with_suggestions, updated_items)}
  end

  @impl true
  def handle_event(
        "select_product",
        %{"index" => index_str, "product_id" => product_id_str},
        socket
      ) do
    index = String.to_integer(index_str)
    product_id = String.to_integer(product_id_str)

    product =
      Inventory.get_product!(socket.assigns.tenant_id, product_id)
      |> CyberCore.Repo.preload(:measurement_unit)

    line_items = socket.assigns.line_items_with_suggestions

    updated_line =
      line_items
      |> Enum.at(index)
      |> Map.put(:product, product)
      |> Map.put(:product_id, product_id)
      |> Map.put(:auto_select, false)

    updated_items = List.replace_at(line_items, index, updated_line)

    {:noreply, assign(socket, :line_items_with_suggestions, updated_items)}
  end

  @impl true
  def handle_event("search_products", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Inventory.search_products(socket.assigns.tenant_id, query, limit: 10)
      else
        []
      end

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:product_search_results, results)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_line_item", _params, socket) do
    new_item = %{
      description: "",
      quantity: Decimal.new(1),
      unit_price: Decimal.new(0),
      total: Decimal.new(0),
      product: nil,
      product_id: nil,
      confidence: Decimal.new(0),
      auto_select: false,
      suggestions: [],
      vat_rate: Decimal.new("0.20"),
      payment_method: "bank",
      notes: ""
    }

    updated_items = socket.assigns.line_items_with_suggestions ++ [new_item]

    {:noreply, assign(socket, :line_items_with_suggestions, updated_items)}
  end

  @impl true
  def handle_event("delete_line_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    updated_items = List.delete_at(socket.assigns.line_items_with_suggestions, index)

    {:noreply, assign(socket, :line_items_with_suggestions, updated_items)}
  end

  @impl true
  def handle_event("save_invoice", _params, socket) do
    extracted_invoice = socket.assigns.current_invoice
    line_items = socket.assigns.line_items_with_suggestions
    contact = socket.assigns.contact

    errors = validate_invoice(extracted_invoice, line_items, contact)

    if errors == [] do
      result =
        case extracted_invoice.invoice_type do
          "purchase" ->
            create_purchase_invoice(socket, extracted_invoice, contact, line_items, socket.assigns.accounting_settings)

          "sales" ->
            create_sales_invoice(socket, extracted_invoice, contact, line_items, socket.assigns.accounting_settings)
        end

      case result do
        {:ok, invoice} ->
          path =
            if extracted_invoice.invoice_type == "purchase" do
              ~p"/supplier-invoices/#{invoice.id}/edit"
            else
              ~p"/invoices/#{invoice.id}"
            end

          socket =
            socket
            |> put_flash(:info, "Фактура е създадена успешно.")
            |> push_navigate(to: path)

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply,
           put_flash(socket, :error, "Грешка при създаване на фактура: #{inspect(changeset)}")}
      end
    else
      error_message =
        "❌ Не може да се запази:\n" <> Enum.map_join(errors, "\n", &"  • #{&1}")

      {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("delete_invoice", %{"id" => id}, socket) do
    invoice = DocumentProcessing.get_extracted_invoice!(socket.assigns.tenant_id, id)
    user_id = socket.assigns.user_id

    case DocumentProcessing.reject_extracted_invoice(invoice, user_id, "Изтрита от потребител") do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Фактурата е изтрита")
          |> assign(:show_modal, false)
          |> load_extracted_invoices()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Грешка при изтриване")}
    end
  end

  @impl true
  def handle_event("undo_approval", %{"id" => id}, socket) do
    invoice = DocumentProcessing.get_extracted_invoice!(socket.assigns.tenant_id, id)

    case DocumentProcessing.unapprove_invoice(invoice) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Одобрението е отменено.")
          |> load_extracted_invoices()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Грешка при отмяна: #{reason}")}
    end
  end

  @impl true
  def handle_event("bulk_approve", _params, socket) do
    {approved_count, failed_invoices} =
      Enum.reduce(socket.assigns.selected_ids, {0, []}, fn id, {approved_acc, failed_acc} ->
        extracted_invoice =
          DocumentProcessing.get_extracted_invoice!(socket.assigns.tenant_id, id, preloads: [:document_upload])

        # Load data needed for validation
        {contact, _} =
          ContactMatcher.find_or_create_contact(
            socket.assigns.tenant_id,
            extracted_invoice.vendor_name,
            extracted_invoice.vendor_vat_number,
            extracted_invoice.vendor_address
          )

        line_items_with_suggestions =
          Enum.map(extracted_invoice.line_items || [], fn item ->
            suggestion =
              if contact do
                ProductMapper.suggest_product(
                  contact.id,
                  item["description"] || "",
                  socket.assigns.tenant_id
                )
              else
                %{product: nil, confidence: Decimal.new(0), auto_select: false, suggestions: []}
              end

            %{
              description: item["description"] || "",
              product_id: if(suggestion.product, do: suggestion.product.id, else: nil),
              quantity: Decimal.new(1),
              unit_price: Decimal.new(0),
              total: Decimal.new(0)
            }
          end)

        errors = validate_invoice(extracted_invoice, line_items_with_suggestions, contact)

        if errors == [] do
          result =
            case extracted_invoice.invoice_type do
              "purchase" ->
                create_purchase_invoice(socket, extracted_invoice, contact, line_items_with_suggestions, socket.assigns.accounting_settings)

              "sales" ->
                create_sales_invoice(socket, extracted_invoice, contact, line_items_with_suggestions, socket.assigns.accounting_settings)
            end

          case result do
            {:ok, _} -> {approved_acc + 1, failed_acc}
            {:error, reason} -> {approved_acc, [{extracted_invoice.invoice_number, reason} | failed_acc]}
          end
        else
          {approved_acc, [{extracted_invoice.invoice_number, errors} | failed_acc]}
        end
      end)

    flash_message =
      cond do
        approved_count > 0 and length(failed_invoices) > 0 ->
          "#{approved_count} фактури бяха одобрени. #{length(failed_invoices)} се провалиха:\n" <> format_failed_invoices(failed_invoices)
        approved_count > 0 ->
          "#{approved_count} фактури бяха одобрени."
        length(failed_invoices) > 0 ->
          "Грешка при одобрение на #{length(failed_invoices)} фактури:\n" <> format_failed_invoices(failed_invoices)
        true ->
          "Няма избрани фактури за одобрение."
      end
    flash_type = if length(failed_invoices) > 0, do: :error, else: :info

    socket =
      socket
      |> put_flash(flash_type, flash_message)
      |> assign(:selected_ids, MapSet.new())
      |> load_extracted_invoices()

    {:noreply, socket}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    selected_ids = socket.assigns.selected_ids
    user_id = socket.assigns.user_id

    for id <- selected_ids do
      invoice = DocumentProcessing.get_extracted_invoice!(socket.assigns.tenant_id, id)
      DocumentProcessing.reject_extracted_invoice(invoice, user_id, "Bulk deleted")
    end

    socket =
      socket
      |> put_flash(:info, "#{MapSet.size(selected_ids)} документа са премахнати")
      |> assign(:selected_ids, MapSet.new())
      |> load_extracted_invoices()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    selected_ids = socket.assigns.selected_ids

    selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, selected_ids)}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    selected_ids = socket.assigns.selected_ids
    all_ids = Enum.map(socket.assigns.extracted_invoices, & &1.id) |> MapSet.new()

    selected_ids =
      if MapSet.size(selected_ids) == MapSet.size(all_ids) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply, assign(socket, :selected_ids, selected_ids)}
  end

  @impl true
  def handle_event("update_invoice_field", %{"field" => field, "value" => value}, socket) do
    invoice =
      case field do
        "payment_method" -> Map.put(socket.assigns.current_invoice, :payment_method, value)
        "notes" -> Map.put(socket.assigns.current_invoice, :notes, value)
        _ -> socket.assigns.current_invoice
      end

    {:noreply, assign(socket, :current_invoice, invoice)}
  end

  @impl true
  def handle_event("close_new_product_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_product_modal, false)
      |> assign(:new_product_name, nil)
      |> assign(:product_form_line_index, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:select_product, params}, socket) do
    {:noreply, handle_event("select_product", params, socket)}
  end

  @impl true
  def handle_info({:open_create_product_modal, params}, socket) do
    socket =
      socket
      |> assign(:show_product_modal, true)
      |> assign(:new_product_name, params.name)
      |> assign(:product_form_line_index, params.line_item_index)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:product_created, product}, socket) do
    index = socket.assigns.product_form_line_index
    line_items = socket.assigns.line_items_with_suggestions

    updated_line =
      line_items
      |> Enum.at(index)
      |> Map.put(:product, product)
      |> Map.put(:product_id, product.id)
      |> Map.put(:auto_select, false)

    updated_items = List.replace_at(line_items, index, updated_line)

    socket =
      socket
      |> assign(:line_items_with_suggestions, updated_items)
      |> assign(:show_product_modal, false)
      |> assign(:new_product_name, nil)
      |> assign(:product_form_line_index, nil)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Сканирани Документи")
    |> assign(:show_modal, false)
  end

  defp load_extracted_invoices(socket) do
    invoices =
      DocumentProcessing.list_extracted_invoices(socket.assigns.tenant_id,
        preloads: [:document_upload]
      )
      |> Enum.filter(fn inv -> inv.status in ["pending_review", "approved"] end)

    assign(socket, :extracted_invoices, invoices)
  end

  defp load_line_items_with_suggestions(socket, invoice) do
    # Try to find or create contact for vendor
    {contact, contact_status} =
      case ContactMatcher.find_or_create_contact(
             socket.assigns.tenant_id,
             invoice.vendor_name,
             invoice.vendor_vat_number,
             invoice.vendor_address
           ) do
        {:ok, %{inserted_at: i, updated_at: u} = contact} when i == u ->
          {contact, :created}

        {:ok, contact} ->
          {contact, :found}

        {:error, _changeset} ->
          {nil, :error}
      end

    # Check if bank account is known
    bank_account_info =
      if contact && invoice.vendor_bank_iban do
        case ContactBankAccountMapper.find_contact_by_iban(
               invoice.vendor_bank_iban,
               socket.assigns.tenant_id
             ) do
          nil ->
            # New bank account
            %{known: false, times_seen: 0, is_primary: false}

          found_contact when found_contact.id == contact.id ->
            # Known bank account for this contact
            bank_accounts =
              ContactBankAccountMapper.list_bank_accounts_for_contact(
                contact.id,
                socket.assigns.tenant_id
              )

            matching_account =
              Enum.find(bank_accounts, fn ba -> ba.iban == invoice.vendor_bank_iban end)

            if matching_account do
              %{known: true, times_seen: matching_account.times_seen, is_primary: matching_account.is_primary}
            else
              %{known: false, times_seen: 0, is_primary: false}
            end

          _other_contact ->
            # IBAN belongs to different contact! Warning!
            %{known: false, times_seen: 0, is_primary: false, warning: "IBAN belongs to different contact"}
        end
      else
        nil
      end

    # Get suggestions for each line item
    line_items_with_suggestions =
      Enum.map(invoice.line_items || [], fn item ->
        suggestion =
          if contact do
            ProductMapper.suggest_product(
              contact.id,
              item["description"] || "",
              socket.assigns.tenant_id
            )
          else
            %{product: nil, confidence: Decimal.new(0), auto_select: false, suggestions: []}
          end

        %{description: item["description"] || "",
          quantity: parse_decimal(item["quantity"]) || Decimal.new(1),
          unit_price: parse_decimal(item["unit_price"]) || Decimal.new(0),
          total: parse_decimal(item["total"]) || Decimal.new(0),
          product: suggestion.product,
          product_id: if(suggestion.product, do: suggestion.product.id, else: nil),
          confidence: suggestion.confidence,
          auto_select: suggestion.auto_select,
          suggestions: suggestion.suggestions,
          vat_rate: Decimal.new("0.20"),
          payment_method: "bank",
          notes: ""
        }
      end)

    socket
    |> assign(:line_items_with_suggestions, line_items_with_suggestions)
    |> assign(:contact, contact)
    |> assign(:contact_status, contact_status)
    |> assign(:bank_account_info, bank_account_info)
  end

  defp update_line_field(line, "description", value), do: Map.put(line, :description, value)

  defp update_line_field(line, "quantity", value),
    do: Map.put(line, :quantity, parse_decimal(value))

  defp update_line_field(line, "unit_price", value),
    do: Map.put(line, :unit_price, parse_decimal(value))

  defp update_line_field(line, "total", value), do: Map.put(line, :total, parse_decimal(value))
  defp update_line_field(line, "vat_rate", value), do: Map.put(line, :vat_rate, parse_decimal(value))
  defp update_line_field(line, _, _), do: line

  defp parse_decimal(nil), do: Decimal.new(0)

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(%Decimal{} = value), do: value
  defp parse_decimal(value) when is_number(value), do: Decimal.new(value)
  defp parse_decimal(_), do: Decimal.new(0)

  defp validate_invoice(invoice, line_items, contact) do
    errors = []

    errors =
      if is_nil(contact) do
        ["Липсва контрагент" | errors]
      else
        errors
      end

    errors =
      if is_nil(invoice.invoice_date) do
        ["Липсва дата на фактурата" | errors]
      else
        errors
      end

    errors =
      if invoice.total_amount <= 0 do
        ["Сумата на фактурата трябва да е по-голяма от 0" | errors]
      else
        errors
      end

    line_item_errors =
      line_items
      |> Enum.with_index(1)
      |> Enum.reduce([], fn {{item, index}, acc} ->
        if is_nil(item.product_id) do
          ["Моля изберете продукт за ред #{index}" | acc]
        else
          acc
        end
      end)

    Enum.reverse(errors) ++ Enum.reverse(line_item_errors)
  end

  defp create_purchase_invoice(socket, extracted, contact, line_items, accounting_settings) do
    user_id = socket.assigns.user_id

    invoice_attrs = %{
      "tenant_id" => extracted.tenant_id,
      "contact_id" => contact.id,
      "invoice_number" => extracted.invoice_number,
      "invoice_date" => extracted.invoice_date,
      "due_date" => extracted.due_date,
      "subtotal" => extracted.subtotal,
      "tax_amount" => extracted.tax_amount,
      "total_amount" => extracted.total_amount,
      "currency" => extracted.currency,
      "status" => "draft"
    }
    lines_attrs =
      Enum.map(line_items, fn item ->
        %{ "product_id" => item.product_id,
          "description" => item.description,
          "quantity" => item.quantity,
          "unit_price" => item.unit_price,
          "tax_rate" => 0.2, # TODO: make this configurable
          "tax_amount" => item.total - item.unit_price * item.quantity,
          "total_price" => item.total
        }
      end)

    case Purchase.create_supplier_invoice_with_lines(invoice_attrs, lines_attrs) do
      {:ok, supplier_invoice} ->
        # Preload necessary relations for journal entry creation
        supplier_invoice = Repo.preload(supplier_invoice, [supplier_invoice_lines: [product: :account]])

        # Create Journal Entry
        entry_attrs = %{
          tenant_id: supplier_invoice.tenant_id,
          document_date: supplier_invoice.invoice_date,
          description: "Покупка от #{contact.name}, фактура #{supplier_invoice.invoice_number}",
          created_by_id: user_id,
          source_document_id: supplier_invoice.id,
          source_document_type: "SupplierInvoice"
        }
        
        expense_lines = Enum.map(supplier_invoice.supplier_invoice_lines, fn line ->
          debit_account_id = 
            case line.product.category do
              "goods" -> accounting_settings.inventory_goods_account_id
              "materials" -> accounting_settings.inventory_materials_account_id
              "services" -> line.product.account_id
              _ -> line.product.account_id # Fallback to product's account
            end
          %{
            account_id: debit_account_id,
            debit_amount: line.subtotal,
            credit_amount: 0,
            reference_id: line.id # Add reference_id here
          }
        end)
        vat_line = %{
          account_id: accounting_settings.vat_purchases_account_id,
          debit_amount: supplier_invoice.tax_amount,
          credit_amount: 0
        }
        supplier_line = %{
          account_id: accounting_settings.suppliers_account_id,
          debit_amount: 0,
          credit_amount: supplier_invoice.total_amount
        }
        journal_lines = expense_lines ++ [vat_line, supplier_line]

        Accounting.create_journal_entry_with_lines(entry_attrs, journal_lines)

        DocumentProcessing.mark_as_converted(
          extracted,
          supplier_invoice.id,
          "supplier_invoice"
        )
        {:ok, supplier_invoice}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_sales_invoice(socket, extracted, contact, line_items, accounting_settings) do
    user_id = socket.assigns.user_id
    
    invoice_attrs = %{
      "tenant_id" => extracted.tenant_id,
      "contact_id" => contact.id,
      "invoice_number" => extracted.invoice_number,
      "invoice_date" => extracted.invoice_date,
      "due_date" => extracted.due_date,
      "subtotal" => extracted.subtotal,
      "tax_amount" => extracted.tax_amount,
      "total_amount" => extracted.total_amount,
      "currency" => extracted.currency,
      "status" => "draft"
    }
    lines_attrs =
      Enum.map(line_items, fn item ->
        %{ "product_id" => item.product_id,
          "description" => item.description,
          "quantity" => item.quantity,
          "unit_price" => item.unit_price,
          "tax_rate" => 0.2, # TODO: make this configurable
          "tax_amount" => item.total - item.unit_price * item.quantity,
          "total_price" => item.total
        }
      end)

    case Sales.create_invoice_with_lines(invoice_attrs, lines_attrs) do
      {:ok, invoice} ->
        invoice = Repo.preload(invoice, [invoice_lines: [product: :account]])
        # Create Journal Entry for Sale
        entry_attrs = %{
          tenant_id: invoice.tenant_id,
          document_date: invoice.invoice_date,
          description: "Продажба на #{contact.name}, фактура #{invoice.invoice_number}",
          created_by_id: user_id,
          source_document_id: invoice.id,
          source_document_type: "SalesInvoice"
        }
        customer_line = %{
          account_id: accounting_settings.customers_account_id,
          debit_amount: invoice.total_amount,
          credit_amount: 0
        }
        # Create individual income lines for each invoice line
        income_lines = Enum.map(invoice.invoice_lines, fn line ->
          %{
            account_id: accounting_settings.default_income_account_id, # Or line.product.income_account_id if available
            debit_amount: 0,
            credit_amount: line.subtotal,
            reference_id: line.id # Add reference_id here
          }
        end)
        vat_line = %{
          account_id: accounting_settings.vat_sales_account_id,
          debit_amount: 0,
          credit_amount: invoice.tax_amount
        }
        journal_lines = [customer_line] ++ income_lines ++ [vat_line]

        Accounting.create_journal_entry_with_lines(entry_attrs, journal_lines)

        # Create Journal Entry for COGS
        cogs_lines = Enum.map(invoice.invoice_lines, fn line ->
          if line.product.category in ["goods", "produced"] do
            cogs_account_id = accounting_settings.cogs_account_id
            inventory_account_id =
              case line.product.category do
                "goods" -> accounting_settings.inventory_goods_account_id
                "produced" -> accounting_settings.inventory_produced_account_id
              end
            
            [
              %{account_id: cogs_account_id, debit_amount: line.product.cost * line.quantity, credit_amount: 0, reference_id: line.id},
              %{account_id: inventory_account_id, debit_amount: 0, credit_amount: line.product.cost * line.quantity, reference_id: line.id}
            ]
          else
            []
          end
        end) |> List.flatten()

        if cogs_lines != [] do
          cogs_entry_attrs = %{
            tenant_id: invoice.tenant_id,
            document_date: invoice.invoice_date,
            description: "Себестойност за фактура #{invoice.invoice_number}",
            created_by_id: user_id,
            source_document_id: invoice.id,
            source_document_type: "SalesInvoice"
          }
          Accounting.create_journal_entry_with_lines(cogs_entry_attrs, cogs_lines)
        end
        
        DocumentProcessing.mark_as_converted(
          extracted,
          invoice.id,
          "invoice"
        )
        {:ok, invoice}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp format_failed_invoices(failed_invoices) do
    Enum.map_join(failed_invoices, "\n", fn {inv_num, reason} ->
      "  • #{inv_num}: #{format_error_reason(reason)}"
    end)
  end

  defp format_error_reason(reason) when is_list(reason) do
    Enum.join(reason, ", ")
  end

  defp format_error_reason(reason) do
    inspect(reason)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Сканирани Документи</h1>
          <p class="mt-2 text-sm text-gray-700">
            Преглед и одобрение на автоматично извлечени данни от фактури
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex gap-2">
          <%= if MapSet.size(@selected_ids) > 0 do %>
            <button
              type="button"
              phx-click="bulk_approve"
              class="block rounded-md bg-green-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-green-500"
            >
              ОДОБРИ ИЗБРАНИТЕ (<%= MapSet.size(@selected_ids) %>)
            </button>
            <button
              type="button"
              phx-click="bulk_delete"
              class="block rounded-md bg-red-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-red-500"
            >
              ИЗТРИЙ ИЗБРАНИТЕ (<%= MapSet.size(@selected_ids) %>)
            </button>
          <% else %>
            <.link
              href={~p"/documents/upload"}
              class="block rounded-md bg-teal-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-teal-500"
            >
              + ДОБАВИ ДОКУМЕНТИ
            </.link>
            <button
              type="button"
              phx-click="bulk_delete"
              class="block rounded-md bg-orange-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-orange-500"
            >
              ПРЕМАХНИ ВСИЧКИ ДОКУМЕНТИ
            </button>
          <% end %>
        </div>
      </div>

      <%= if @extracted_invoices == [] do %>
        <!-- Няма фактури -->
        <div class="mt-12 text-center">
          <svg
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-semibold text-gray-900">
            Няма извлечени фактури
          </h3>
          <p class="mt-1 text-sm text-gray-500">
            Започнете с качване на PDF документи за обработка
          </p>
        </div>
      <% else %>
        <!-- Table View -->
        <div class="mt-8 flow-root">
          <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <%= if MapSet.size(@selected_ids) > 0 do %>
                <p class="mb-2 text-sm text-gray-600">Избрани: <%= MapSet.size(@selected_ids) %></p>
              <% end %>
              <table class="min-w-full divide-y divide-gray-300">
                <thead>
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0 w-10">
                      <input
                        type="checkbox"
                        phx-click="toggle_select_all"
                        checked={MapSet.size(@selected_ids) == length(@extracted_invoices) && length(@extracted_invoices) > 0}
                        class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                      />
                    </th>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0">
                      Статус
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      № Фактура
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Доставчик
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Дата
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Сума
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                      Валута
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                      <span class="sr-only">Действия</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                  <%= for invoice <- @extracted_invoices do %>
                    <tr class="hover:bg-gray-50 cursor-pointer" phx-click="open_invoice" phx-value-id={invoice.id}>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-0" onclick="event.stopPropagation();">
                        <input
                          type="checkbox"
                          phx-click="toggle_select"
                          phx-value-id={invoice.id}
                          checked={MapSet.member?(@selected_ids, invoice.id)}
                          class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                        />
                      </td>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-0">
                        <%= status_badge(%{status: invoice.status}) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                        <%= invoice.invoice_number %>
                      </td>
                      <td class="px-3 py-4 text-sm text-gray-900 max-w-xs truncate">
                        <%= invoice.vendor_name %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= if invoice.invoice_date, do: Calendar.strftime(invoice.invoice_date, "%d.%m.%Y"), else: "-" %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-right text-gray-900 font-medium">
                        <%= Decimal.to_string(invoice.total_amount) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-center text-gray-500">
                        <%= invoice.currency %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                        <%= if invoice.status == "approved" do %>
                          <button
                            type="button"
                            class="text-blue-600 hover:text-blue-900"
                            phx-click="undo_approval"
                            phx-value-id={invoice.id}
                            onclick="event.stopPropagation();"
                          >
                            Върни в очакващи<span class="sr-only">, <%= invoice.invoice_number %></span>
                          </button>
                        <% else %>
                          <button
                            type="button"
                            class="text-indigo-600 hover:text-indigo-900"
                            phx-click="open_invoice"
                            phx-value-id={invoice.id}
                            onclick="event.stopPropagation();"
                          >
                            Редактирай<span class="sr-only">, <%= invoice.invoice_number %></span>
                          </button>
                        <% end %>
                        <button
                          type="button"
                          phx-click="delete_invoice"
                          phx-value-id={invoice.id}
                          class="ml-4 text-red-600 hover:text-red-900"
                          onclick="event.stopPropagation();"
                        >
                          Изтрий<span class="sr-only">, <%= invoice.invoice_number %></span>
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Modal Editor -->
      <%= if @show_modal && @current_invoice do %>
        <div
          class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-40"
          phx-click="close_modal"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
        </div>

        <div class="fixed inset-0 z-50 overflow-y-auto" id="invoice-modal"
          phx-window-keydown="save_invoice"
          phx-key="enter"
        >
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg shadow-xl w-full max-w-6xl max-h-[90vh] flex flex-col" phx-click="stop_propagation">
              <!-- Modal Header with Navigation -->
              <div class="bg-gray-800 px-6 py-4 rounded-t-lg flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <button
                    type="button"
                    phx-click="previous_invoice"
                    disabled={@current_index == 0}
                    class="text-white disabled:text-gray-500 disabled:cursor-not-allowed hover:text-gray-300 p-2"
                  >
                    ← Назад
                  </button>
                  <span class="text-white text-sm font-medium">
                    <%= @current_index + 1 %> от <%= length(@extracted_invoices) %>
                  </span>
                  <button
                    type="button"
                    phx-click="next_invoice"
                    disabled={@current_index == length(@extracted_invoices) - 1}
                    class="text-white disabled:text-gray-500 disabled:cursor-not-allowed hover:text-gray-300 p-2"
                  >
                    Напред →
                  </button>
                </div>
                <h2 class="text-lg font-semibold text-white">
                  Редакция на фактура <%= @current_invoice.invoice_number %>
                </h2>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="text-white hover:text-gray-300 text-2xl"
                >
                  ×
                </button>
              </div>

              <!-- Modal Content (scrollable) -->
              <div class="flex-1 overflow-y-auto p-6">
                <!-- Invoice Header Info -->
                <div class="grid grid-cols-3 gap-4 mb-6">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Документ №</label>
                    <input
                      type="text"
                      value={@current_invoice.invoice_number}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      readonly
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Дата</label>
                    <input
                      type="text"
                      value={if @current_invoice.invoice_date, do: Calendar.strftime(@current_invoice.invoice_date, "%d.%m.%Y"), else: ""}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      readonly
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Валута</label>
                    <input
                      type="text"
                      value={@current_invoice.currency}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      readonly
                    />
                  </div>
                  <div class="col-span-3">
                    <label class="block text-sm font-medium text-gray-700">Доставчик</label>
                    <input
                      type="text"
                      value={@current_invoice.vendor_name}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      readonly
                    />
                    <%= case @contact_status do %>
                      <% :found -> %>
                        <p class="mt-1 text-xs text-green-600">✓ Намерен съществуващ контакт: <%= @contact.name %></p>
                      <% :created -> %>
                        <p class="mt-1 text-xs text-blue-600">➕ Създаден нов контакт: <%= @contact.name %></p>
                      <% :error -> %>
                        <p class="mt-1 text-xs text-red-600">❌ Грешка при създаване на контакт.</p>
                      <% _ -> %>
                        <p class="mt-1 text-xs text-gray-500">Зареждане...</p>
                    <% end %>
                  </div>

                  <!-- Bank Account Information -->
                  <%= if @current_invoice.vendor_bank_iban do %>
                    <div class="col-span-3 bg-blue-50 border border-blue-200 rounded-lg p-4">
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <h4 class="text-sm font-semibold text-gray-900 mb-2">Банкова сметка на доставчика</h4>
                          <div class="grid grid-cols-2 gap-2 text-xs">
                            <div>
                              <span class="text-gray-600">IBAN:</span>
                              <span class="ml-2 font-mono font-medium"><%= @current_invoice.vendor_bank_iban %></span>
                            </div>
                            <%= if @current_invoice.vendor_bank_bic do %>
                              <div>
                                <span class="text-gray-600">BIC:</span>
                                <span class="ml-2 font-mono font-medium"><%= @current_invoice.vendor_bank_bic %></span>
                              </div>
                            <% end %>
                            <%= if @current_invoice.vendor_bank_name do %>
                              <div class="col-span-2">
                                <span class="text-gray-600">Банка:</span>
                                <span class="ml-2 font-medium"><%= @current_invoice.vendor_bank_name %></span>
                              </div>
                            <% end %>
                          </div>
                        </div>
                        <div class="ml-4">
                          <%= if @bank_account_info do %>
                            <%= if @bank_account_info.known do %>
                              <div class="bg-green-100 text-green-800 px-3 py-1 rounded-full text-xs font-medium">
                                ✓ Позната сметка
                                <%= if @bank_account_info.times_seen > 0 do %>
                                  (<%= @bank_account_info.times_seen %>x)
                                <% end %>
                              </div>
                              <%= if @bank_account_info.is_primary do %>
                                <div class="mt-1 text-xs text-green-600">★ Главна сметка</div>
                              <% end %>
                            <% else %>
                              <%= if Map.get(@bank_account_info, :warning) do %>
                                <div class="bg-red-100 text-red-800 px-3 py-1 rounded-full text-xs font-medium">
                                  ⚠ Друг контакт!
                                </div>
                              <% else %>
                                <div class="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-xs font-medium">
                                  • Нова сметка
                                </div>
                              <% end %>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                      <p class="mt-2 text-xs text-gray-600">
                        💡 Сметката ще бъде запазена за автоматично матчване на плащания
                      </p>
                    </div>
                  <% end %>
                </div>

                <!-- Line Items Table -->
                <div class="mb-6">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="text-sm font-semibold text-gray-900">Артикули</h3>
                    <button
                      type="button"
                      phx-click="add_line_item"
                      class="text-sm text-teal-600 hover:text-teal-700 font-medium"
                    >
                      + Добави артикул
                    </button>
                  </div>

                  <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-300 border">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Описание</th>
                          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-48">Продукт</th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase w-20">Кол.</th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase w-24">Цена</th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase w-24">ДДС %</th>
                          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase w-24">Общо</th>
                          <th class="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase w-16"></th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-200 bg-white">
                        <%= for {item, index} <- Enum.with_index(@line_items_with_suggestions) do %>
                          <tr>
                            <td class="px-3 py-3">
                              <input
                                type="text"
                                value={item.description}
                                phx-blur="update_line_item"
                                phx-value-index={index}
                                phx-value-field="description"
                                class="w-full rounded-md border-gray-300 text-sm"
                              />
                            </td>
                            <td class="px-3 py-3">
                              <%= if item.product do %>
                                <div class={[ "text-sm p-2 rounded", if(item.auto_select, do: "bg-green-50 border border-green-200", else: "bg-gray-50") ]}>
                                  <div class="font-medium text-gray-900">
                                    <%= item.product.name %>
                                    <%= if item.auto_select do %>
                                      <span class="ml-1 text-xs text-green-600">(#{Decimal.round(item.confidence, 0)}%)</span>
                                    <% end %>
                                  </div>
                                  <div class="text-xs text-gray-500"><%= item.product.code %></div>
                                </div>
                              <% else %>
                                <.live_component
                                  module={CyberWeb.ExtractedInvoiceLive.ProductSearchComponent}
                                  id={"product-search-#{index}"}
                                  line_item_index={index}
                                  current_tenant_id={@tenant_id}
                                  target={@socket.id}
                                />
                              <% end %>
                            </td>
                            <td class="px-3 py-3">
                              <input
                                type="number"
                                value={Decimal.to_string(item.quantity)}
                                phx-blur="update_line_item"
                                phx-value-index={index}
                                phx-value-field="quantity"
                                step="0.01"
                                class="w-full rounded-md border-gray-300 text-sm text-right"
                              />
                            </td>
                            <td class="px-3 py-3">
                              <input
                                type="number"
                                value={Decimal.to_string(item.unit_price)}
                                phx-blur="update_line_item"
                                phx-value-index={index}
                                phx-value-field="unit_price"
                                step="0.01"
                                class="w-full rounded-md border-gray-300 text-sm text-right"
                              />
                            </td>
                            <td class="px-3 py-3">
                              <select
                                phx-change="update_line_item"
                                phx-value-index={index}
                                phx-value-field="vat_rate"
                                class="w-full rounded-md border-gray-300 text-sm"
                              >
                                <option value="0.20" selected={item.vat_rate == Decimal.new("0.20")}>20%</option>
                                <option value="0.09" selected={item.vat_rate == Decimal.new("0.09")}>9%</option>
                                <option value="0.00" selected={item.vat_rate == Decimal.new("0.00")}>0%</option>
                              </select>
                            </td>
                            <td class="px-3 py-3 text-right font-medium">
                              <%= Decimal.to_string(item.total) %>
                            </td>
                            <td class="px-3 py-3 text-center">
                              <button
                                type="button"
                                phx-click="delete_line_item"
                                phx-value-index={index}
                                class="text-red-600 hover:text-red-900 text-sm"
                              >
                                🗑
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>

                <!-- END OF Line Items Table -->
                <div class="grid grid-cols-2 gap-6 mt-6">
                  <div>
                    <label for="payment_method" class="block text-sm font-medium text-gray-700">Начин на плащане</label>
                    <select
                      id="payment_method"
                      phx-change="update_invoice_field"
                      phx-value-field="payment_method"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    >
                      <option value="bank" selected={"bank" == @current_invoice.payment_method}>По банка</option>
                      <option value="cash" selected={"cash" == @current_invoice.payment_method}>В брой</option>
                    </select>
                  </div>
                  <div>
                    <label for="notes" class="block text-sm font-medium text-gray-700">Бележки</label>
                    <textarea
                      id="notes"
                      rows="3"
                      phx-blur="update_invoice_field"
                      phx-value-field="notes"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                    ><%= @current_invoice.notes %></textarea>
                  </div>
                </div>
              </div>

              <!-- Modal Footer with Actions -->
              <div class="bg-gray-50 px-6 py-4 rounded-b-lg flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="rounded-md bg-white px-4 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                >
                  Отказ (Esc)
                </button>
                <button
                  type="button"
                  phx-click="save_invoice"
                  class="rounded-md bg-teal-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-teal-500"
                >
                  Запази и одобри (Ctrl+Enter)
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- New Product Modal -->
      <%= if @show_product_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50"></div>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg shadow-xl w-full max-w-2xl p-6">
              <.live_component
                module={CyberWeb.ProductLive.FormComponent}
                id="new-product-from-invoice"
                title="Създаване на нов продукт"
                action={:new}
                product={%CyberCore.Inventory.Product{name: @new_product_name, tenant_id: @tenant_id}}
                patch={~p"/products"}
                current_tenant_id={@tenant_id}
                parent={@socket.id}
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge(assigns) do
    status = assigns.status

    case status do
      "pending_review" ->
        ~H"""
        <span class="inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-800 ring-1 ring-inset ring-yellow-600/20">
          За преглед
        </span>
        """

      "approved" ->
        ~H"""
        <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
          Одобрен
        </span>
        """

      "rejected" ->
        ~H"""
        <span class="inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/20">
          Отхвърлен
        </span>
        """
    end
  end
end