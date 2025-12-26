alias CyberCore.Repo
alias CyberCore.Sales.{Invoice, InvoiceLine}
alias CyberCore.Contacts.Contact
alias CyberCore.Inventory.Product
alias CyberCore.Bank.BankAccount

# Cleanup existing test data
IO.puts("🧹 Cleaning up existing invoices...")
Repo.delete_all(InvoiceLine)
Repo.delete_all(Invoice)

# Ensure we have at least one contact
contact =
  case Repo.all(Contact) |> List.first() do
    nil ->
      IO.puts("📇 Creating test contact...")
      %Contact{}
      |> Contact.changeset(%{
        tenant_id: 1,
        name: "ТЕСТОВА ФИРМА ЕООД",
        company: "ТЕСТОВА ФИРМА ЕООД",
        vat_number: "BG123456789",
        registration_number: "123456789",
        email: "test@example.com",
        address: "гр. София, бул. Витоша 1",
        is_company: true,
        is_customer: true
      })
      |> Repo.insert!()

    contact ->
      IO.puts("✅ Using existing contact: #{contact.name}")
      contact
  end

# Ensure we have at least one bank account
bank_account =
  case Repo.all(BankAccount) |> List.first() do
    nil ->
      IO.puts("🏦 Creating test bank account...")
      %BankAccount{}
      |> BankAccount.changeset(%{
        tenant_id: 1,
        account_no: "10200001234567",
        iban: "BG80BNBG96611020345678",
        bic: "BNBGBGSD",
        bank_name: "УниКредит Булбанк",
        account_type: "current",
        currency: "BGN",
        is_active: true,
        initial_balance: Decimal.new("0")
      })
      |> Repo.insert!()

    account ->
      IO.puts("✅ Using existing bank account: #{account.bank_name}")
      account
  end

# Get some products if they exist (for future use)
_products = Repo.all(Product) |> Enum.take(3)

IO.puts("📄 Creating test invoices...")

# Invoice 1: Standard invoice with VAT
invoice1 =
  %Invoice{}
  |> Invoice.changeset(%{
    tenant_id: 1,
    invoice_no: "INV-2025-001",
    invoice_type: "standard",
    status: "issued",
    issue_date: ~D[2025-01-15],
    due_date: ~D[2025-02-15],
    tax_event_date: ~D[2025-01-15],
    contact_id: contact.id,
    billing_name: contact.company || contact.name,
    billing_address: contact.address,
    billing_vat_number: contact.vat_number,
    billing_company_id: contact.registration_number,
    currency: "BGN",
    payment_method: "bank",
    bank_account_id: bank_account.id,
    vat_document_type: "01",
    vat_sales_operation: "2",
    notes: "Плащане по банков път в срок до 30 дни",
    payment_terms: "30 дни от дата на фактура"
  })
  |> Repo.insert!()

# Invoice 1 Lines
lines1 = [
  %{
    description: "Консултантски услуги - януари 2025",
    quantity: Decimal.new("1"),
    unit_of_measure: "услуга",
    unit_price: Decimal.new("1200.00"),
    tax_rate: Decimal.new("20.0"),
    discount_percent: Decimal.new("0")
  },
  %{
    description: "Софтуерна поддръжка - месечна абонаментна такса",
    quantity: Decimal.new("1"),
    unit_of_measure: "бр.",
    unit_price: Decimal.new("350.00"),
    tax_rate: Decimal.new("20.0"),
    discount_percent: Decimal.new("10")
  },
  %{
    description: "Допълнителни часове разработка",
    quantity: Decimal.new("8"),
    unit_of_measure: "часа",
    unit_price: Decimal.new("75.00"),
    tax_rate: Decimal.new("20.0"),
    discount_percent: Decimal.new("0")
  }
]

Enum.with_index(lines1, 1)
|> Enum.each(fn {line_data, index} ->
  %InvoiceLine{}
  |> InvoiceLine.changeset(
    Map.merge(line_data, %{
      tenant_id: 1,
      invoice_id: invoice1.id,
      line_no: index
    })
  )
  |> Repo.insert!()
end)

# Update invoice1 totals
invoice1_lines = Repo.all(Ecto.assoc(invoice1, :invoice_lines))

subtotal1 =
  Enum.reduce(invoice1_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.subtotal)
  end)

tax_amount1 =
  Enum.reduce(invoice1_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.tax_amount)
  end)

total_amount1 =
  Enum.reduce(invoice1_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.total_amount)
  end)

invoice1
|> Invoice.changeset(%{
  subtotal: subtotal1,
  tax_amount: tax_amount1,
  total_amount: total_amount1
})
|> Repo.update!()

IO.puts("✅ Created invoice: #{invoice1.invoice_no} - Total: #{total_amount1} BGN")

# Invoice 2: Intra-Community Supply (0% VAT)
invoice2 =
  %Invoice{}
  |> Invoice.changeset(%{
    tenant_id: 1,
    invoice_no: "INV-2025-002",
    invoice_type: "standard",
    status: "issued",
    issue_date: ~D[2025-01-20],
    due_date: ~D[2025-02-20],
    tax_event_date: ~D[2025-01-20],
    contact_id: contact.id,
    billing_name: "German Client GmbH",
    billing_address: "Berlin, Germany",
    billing_vat_number: "DE123456789",
    billing_company_id: "HRB 12345",
    currency: "EUR",
    payment_method: "bank",
    bank_account_id: bank_account.id,
    vat_document_type: "01",
    vat_sales_operation: "3",
    vat_reason: "vod",
    notes: "Вътреобщностна доставка - чл. 53 от ЗДДС",
    payment_terms: "Предплащане"
  })
  |> Repo.insert!()

# Invoice 2 Lines
lines2 = [
  %{
    description: "Лаптоп Dell Latitude 5540",
    quantity: Decimal.new("5"),
    unit_of_measure: "бр.",
    unit_price: Decimal.new("850.00"),
    tax_rate: Decimal.new("0"),
    discount_percent: Decimal.new("0")
  },
  %{
    description: "Монитор Dell 27\"",
    quantity: Decimal.new("5"),
    unit_of_measure: "бр.",
    unit_price: Decimal.new("280.00"),
    tax_rate: Decimal.new("0"),
    discount_percent: Decimal.new("5")
  }
]

Enum.with_index(lines2, 1)
|> Enum.each(fn {line_data, index} ->
  %InvoiceLine{}
  |> InvoiceLine.changeset(
    Map.merge(line_data, %{
      tenant_id: 1,
      invoice_id: invoice2.id,
      line_no: index
    })
  )
  |> Repo.insert!()
end)

# Update invoice2 totals
invoice2_lines = Repo.all(Ecto.assoc(invoice2, :invoice_lines))

subtotal2 =
  Enum.reduce(invoice2_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.subtotal)
  end)

tax_amount2 = Decimal.new(0)
total_amount2 = subtotal2

invoice2
|> Invoice.changeset(%{
  subtotal: subtotal2,
  tax_amount: tax_amount2,
  total_amount: total_amount2
})
|> Repo.update!()

IO.puts("✅ Created invoice: #{invoice2.invoice_no} - Total: #{total_amount2} EUR (0% VAT - ВОД)")

# Invoice 3: Credit Note
invoice3 =
  %Invoice{}
  |> Invoice.changeset(%{
    tenant_id: 1,
    invoice_no: "CN-2025-001",
    invoice_type: "credit_note",
    status: "issued",
    issue_date: ~D[2025-01-22],
    due_date: ~D[2025-01-22],
    tax_event_date: ~D[2025-01-22],
    contact_id: contact.id,
    billing_name: contact.company || contact.name,
    billing_address: contact.address,
    billing_vat_number: contact.vat_number,
    billing_company_id: contact.registration_number,
    currency: "BGN",
    payment_method: "bank",
    bank_account_id: bank_account.id,
    vat_document_type: "03",
    vat_sales_operation: "2",
    parent_invoice_id: invoice1.id,
    notes: "Връщане на дефектна стока от фактура INV-2025-001"
  })
  |> Repo.insert!()

# Invoice 3 Lines
lines3 = [
  %{
    description: "Връщане: Допълнителни часове разработка (4 часа)",
    quantity: Decimal.new("4"),
    unit_of_measure: "часа",
    unit_price: Decimal.new("75.00"),
    tax_rate: Decimal.new("20.0"),
    discount_percent: Decimal.new("0")
  }
]

Enum.with_index(lines3, 1)
|> Enum.each(fn {line_data, index} ->
  %InvoiceLine{}
  |> InvoiceLine.changeset(
    Map.merge(line_data, %{
      tenant_id: 1,
      invoice_id: invoice3.id,
      line_no: index
    })
  )
  |> Repo.insert!()
end)

# Update invoice3 totals
invoice3_lines = Repo.all(Ecto.assoc(invoice3, :invoice_lines))

subtotal3 =
  Enum.reduce(invoice3_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.subtotal)
  end)

tax_amount3 =
  Enum.reduce(invoice3_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.tax_amount)
  end)

total_amount3 =
  Enum.reduce(invoice3_lines, Decimal.new(0), fn line, acc ->
    Decimal.add(acc, line.total_amount)
  end)

invoice3
|> Invoice.changeset(%{
  subtotal: subtotal3,
  tax_amount: tax_amount3,
  total_amount: total_amount3
})
|> Repo.update!()

IO.puts("✅ Created credit note: #{invoice3.invoice_no} - Total: #{total_amount3} BGN")

IO.puts("")
IO.puts("🎉 Successfully created 3 test invoices!")
IO.puts("")
IO.puts("📊 Summary:")
IO.puts("  - #{invoice1.invoice_no}: #{total_amount1} BGN (Standard with VAT)")
IO.puts("  - #{invoice2.invoice_no}: #{total_amount2} EUR (Intra-EU, 0% VAT)")
IO.puts("  - #{invoice3.invoice_no}: -#{total_amount3} BGN (Credit Note)")
IO.puts("")
IO.puts("🌐 View invoices at: http://localhost:4000/invoices")
