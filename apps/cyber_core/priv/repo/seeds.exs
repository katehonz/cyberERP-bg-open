# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CyberCore.Repo.insert!(%CyberCore.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
#
# ⚠️ WARNING: DEFAULT CREDENTIALS
# The users created below use hardcoded passwords ("password123") for
# development and demonstration purposes ONLY.
# DO NOT use these credentials in a production environment.
# Change them immediately after deployment or configure a secure seeding process.

alias CyberCore.Repo
alias CyberCore.Accounts.Tenant
alias CyberCore.Inventory.{Product, Warehouse}
alias CyberCore.Contacts.Contact
alias CyberCore.Accounting.Account
alias CyberCore.Accounting.OssVatRate

# Clear existing data (optional - comment out in production!)
# Repo.delete_all(Product)
# Repo.delete_all(Warehouse)
# Repo.delete_all(Contact)
# Repo.delete_all(Account)
# Repo.delete_all(Tenant)

IO.puts("🌱 Starting seed data...")

# 1. Create Tenant
IO.puts("\n📊 Creating tenant...")

tenant =
  case Repo.get_by(Tenant, slug: "demo") do
    nil ->
      %Tenant{}
      |> Tenant.changeset(%{
        name: "Демо ЕООД",
        slug: "demo"
      })
      |> Repo.insert!()

    existing ->
      existing
  end

IO.puts("✓ Tenant created: #{tenant.name}")

# 2. Create Chart of Accounts
IO.puts("\n💰 Creating chart of accounts...")

accounts_data = [
  # Клас 1 - Активи (Каси и банки)
  %{code: "101", name: "Каса", account_type: :asset, account_class: 1},
  %{code: "102", name: "Разплащателна сметка", account_type: :asset, account_class: 1},

  # Клас 2 - Активи (Материални запаси)
  %{code: "201", name: "Материали", account_type: :asset, account_class: 2},
  %{code: "202", name: "Стоки", account_type: :asset, account_class: 2},
  %{code: "203", name: "Готова продукция", account_type: :asset, account_class: 2},

  # Клас 4 - Активи и пасиви (Вземания и задължения)
  %{code: "401", name: "Доставчици", account_type: :liability, account_class: 4},
  %{code: "411", name: "Клиенти", account_type: :asset, account_class: 4},
  %{code: "453", name: "ДДС за внасяне", account_type: :liability, account_class: 4},

  # Клас 5 - Капитал
  %{code: "501", name: "Основен капитал", account_type: :equity, account_class: 5},
  %{code: "551", name: "Неразпределена печалба", account_type: :equity, account_class: 5},

  # Клас 6 - Разходи
  %{code: "601", name: "Разходи за материали", account_type: :expense, account_class: 6},
  %{code: "602", name: "Разходи за стоки", account_type: :expense, account_class: 6},
  %{code: "611", name: "Разходи за външни услуги", account_type: :expense, account_class: 6},
  %{code: "621", name: "Разходи за персонала", account_type: :expense, account_class: 6},

  # Клас 7 - Приходи
  %{code: "701", name: "Приходи от продажби на стоки", account_type: :revenue, account_class: 7},
  %{code: "702", name: "Приходи от услуги", account_type: :revenue, account_class: 7},
  %{code: "703", name: "Приходи от готова продукция", account_type: :revenue, account_class: 7}
]

for account_data <- accounts_data do
  case Repo.get_by(Account, tenant_id: tenant.id, code: account_data.code) do
    nil ->
      %Account{}
      |> Account.changeset(Map.put(account_data, :tenant_id, tenant.id))
      |> Repo.insert!()

      IO.puts("  ✓ Account #{account_data.code} - #{account_data.name}")

    _existing ->
      IO.puts("  - Account #{account_data.code} already exists")
  end
end

# 3. Create Warehouses
IO.puts("\n🏢 Creating warehouses...")

warehouses_data = [
  %{code: "WH01", name: "Централен склад", location: "София, ул. Примерна 1", is_active: true},
  %{
    code: "WH02",
    name: "Производствен склад",
    location: "София, ул. Примерна 2",
    is_active: true
  },
  %{code: "WH03", name: "Магазин - Център", location: "София, бул. Витоша 100", is_active: true}
]

for wh_data <- warehouses_data do
  case Repo.get_by(Warehouse, tenant_id: tenant.id, code: wh_data.code) do
    nil ->
      warehouse =
        %Warehouse{}
        |> Warehouse.changeset(Map.put(wh_data, :tenant_id, tenant.id))
        |> Repo.insert!()

      IO.puts("  ✓ Warehouse #{warehouse.code} - #{warehouse.name}")

    _existing ->
      IO.puts("  - Warehouse #{wh_data.code} already exists")
  end
end

# 4. Create Contacts (Customers and Suppliers)
IO.puts("\n👥 Creating contacts...")

contacts_data = [
  # Клиенти
  %{
    is_customer: true,
    is_supplier: false,
    name: "АКМЕ ЕООД",
    vat_number: "BG123456789",
    registration_number: "123456789",
    email: "info@acme.bg",
    phone: "+359 2 123 4567",
    address: "София, ул. Примерна 10",
    city: "София",
    country: "BG"
  },
  %{
    is_customer: true,
    is_supplier: false,
    name: "БизнесПартнер ООД",
    vat_number: "BG987654321",
    registration_number: "987654321",
    email: "office@bizpartner.bg",
    phone: "+359 2 987 6543",
    address: "Пловдив, бул. Марица 5",
    city: "Пловдив",
    country: "BG"
  },
  %{
    is_customer: true,
    is_supplier: false,
    name: "ТехноСтрой АД",
    vat_number: "BG111222333",
    registration_number: "111222333",
    email: "techno@technostroy.bg",
    phone: "+359 32 111 222",
    address: "Варна, ул. Морска 15",
    city: "Варна",
    country: "BG"
  },

  # Доставчици
  %{
    is_customer: false,
    is_supplier: true,
    name: "СуровиниБГ ЕООД",
    vat_number: "BG444555666",
    registration_number: "444555666",
    email: "sales@surovini.bg",
    phone: "+359 2 444 5555",
    address: "София, Индустриална зона",
    city: "София",
    country: "BG"
  },
  %{
    is_customer: false,
    is_supplier: true,
    name: "МатериалТрейд ООД",
    vat_number: "BG777888999",
    registration_number: "777888999",
    email: "info@material.bg",
    phone: "+359 2 777 8888",
    address: "Бургас, ул. Индустриална 7",
    city: "Бургас",
    country: "BG"
  },
  %{
    is_customer: false,
    is_supplier: true,
    name: "ЕвроСервиз ЕООД",
    vat_number: "BG333444555",
    registration_number: "333444555",
    email: "office@euroservice.bg",
    phone: "+359 2 333 4444",
    address: "София, бул. България 50",
    city: "София",
    country: "BG"
  }
]

for contact_data <- contacts_data do
  case Repo.get_by(Contact, tenant_id: tenant.id, vat_number: contact_data.vat_number) do
    nil ->
      contact =
        %Contact{}
        |> Contact.changeset(Map.put(contact_data, :tenant_id, tenant.id))
        |> Repo.insert!()

      contact_type = if contact.is_customer, do: "customer", else: "supplier"
      IO.puts("  ✓ Contact #{contact_type}: #{contact.name}")

    _existing ->
      IO.puts("  - Contact #{contact_data.name} already exists")
  end
end

# 5. Create Products
IO.puts("\n📦 Creating products...")

products_data = [
  # СТОКИ (goods) - за търговия
  %{
    sku: "G001",
    name: "Лаптоп Dell Latitude 5420",
    category: "goods",
    description: "14-инчов бизнес лаптоп, Intel Core i5, 8GB RAM, 256GB SSD",
    unit: "бр.",
    price: Decimal.new("1499.00"),
    cost: Decimal.new("1200.00"),
    quantity: 10,
    barcode: "5397184478912",
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "G002",
    name: "Монитор Samsung 27\"",
    category: "goods",
    description: "27-инчов Full HD монитор",
    unit: "бр.",
    price: Decimal.new("349.00"),
    cost: Decimal.new("280.00"),
    quantity: 25,
    barcode: "8806090978234",
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "G003",
    name: "Клавиатура Logitech K120",
    category: "goods",
    description: "USB клавиатура с кирилица",
    unit: "бр.",
    price: Decimal.new("29.90"),
    cost: Decimal.new("18.00"),
    quantity: 50,
    barcode: "5099206042643",
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "G004",
    name: "Мишка Logitech M185",
    category: "goods",
    description: "Безжична оптична мишка",
    unit: "бр.",
    price: Decimal.new("19.90"),
    cost: Decimal.new("12.00"),
    quantity: 75,
    barcode: "5099206055087",
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },

  # МАТЕРИАЛИ (materials) - за производство
  %{
    sku: "M001",
    name: "Стоманена тръба Ø20мм",
    category: "materials",
    description: "Стоманена тръба за конструкции, 6 метра",
    unit: "м",
    price: Decimal.new("8.50"),
    cost: Decimal.new("6.20"),
    quantity: 200,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "M002",
    name: "Стоманен лист 2мм",
    category: "materials",
    description: "Стоманен лист за рязане и обработка",
    unit: "кг",
    price: Decimal.new("3.20"),
    cost: Decimal.new("2.80"),
    quantity: 500,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "M003",
    name: "Боя епоксидна RAL 7035",
    category: "materials",
    description: "Епоксидна боя за метал, сива",
    unit: "л",
    price: Decimal.new("25.00"),
    cost: Decimal.new("18.00"),
    quantity: 50,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "M004",
    name: "Електроди за заваряване Ø3.2мм",
    category: "materials",
    description: "Рутилови електроди, 5кг пакет",
    unit: "пак.",
    price: Decimal.new("35.00"),
    cost: Decimal.new("28.00"),
    quantity: 30,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "M005",
    name: "Винтове М8x20",
    category: "materials",
    description: "Шестограми винтове, 100 бр опаковка",
    unit: "пак.",
    price: Decimal.new("12.00"),
    cost: Decimal.new("8.50"),
    quantity: 100,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },

  # ПРОИЗВЕДЕНА ПРОДУКЦИЯ (produced) - от рецепти
  %{
    sku: "P001",
    name: "Метална рафтова система 2000x1000x400",
    category: "produced",
    description: "Метална рафтова система, 4 рафта, товароносимост 200кг/рафт",
    unit: "бр.",
    price: Decimal.new("320.00"),
    cost: Decimal.new("180.00"),
    quantity: 5,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "P002",
    name: "Работна маса 1500x750x850",
    category: "produced",
    description: "Метална работна маса с плот от стомана",
    unit: "бр.",
    price: Decimal.new("450.00"),
    cost: Decimal.new("260.00"),
    quantity: 3,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "P003",
    name: "Метален шкаф 1800x900x450",
    category: "produced",
    description: "Метален шкаф с 2 врати и 4 рафта",
    unit: "бр.",
    price: Decimal.new("580.00"),
    cost: Decimal.new("340.00"),
    quantity: 2,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },
  %{
    sku: "P004",
    name: "Палетна количка 2500кг",
    category: "produced",
    description: "Ръчна палетна количка, капацитет 2500кг",
    unit: "бр.",
    price: Decimal.new("280.00"),
    cost: Decimal.new("160.00"),
    quantity: 8,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: true
  },

  # УСЛУГИ (services)
  %{
    sku: "S001",
    name: "Монтаж на рафтови системи",
    category: "services",
    description: "Професионален монтаж на рафтови системи на обект",
    unit: "час",
    price: Decimal.new("45.00"),
    cost: Decimal.new("30.00"),
    quantity: 0,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: false
  },
  %{
    sku: "S002",
    name: "Ремонт и поддръжка на компютри",
    category: "services",
    description: "Диагностика и ремонт на компютърна техника",
    unit: "час",
    price: Decimal.new("40.00"),
    cost: Decimal.new("25.00"),
    quantity: 0,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: false
  },
  %{
    sku: "S003",
    name: "Консултации по избор на техника",
    category: "services",
    description: "Професионални консултации",
    unit: "час",
    price: Decimal.new("60.00"),
    cost: Decimal.new("35.00"),
    quantity: 0,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: false
  },
  %{
    sku: "S004",
    name: "Транспорт и доставка",
    category: "services",
    description: "Доставка на обект до 50км",
    unit: "бр.",
    price: Decimal.new("50.00"),
    cost: Decimal.new("30.00"),
    quantity: 0,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: false
  },
  %{
    sku: "S005",
    name: "Заваръчни услуги",
    category: "services",
    description: "Заваряване на метални конструкции",
    unit: "час",
    price: Decimal.new("55.00"),
    cost: Decimal.new("35.00"),
    quantity: 0,
    tax_rate: Decimal.new("20"),
    is_active: true,
    track_inventory: false
  }
]

for product_data <- products_data do
  case Repo.get_by(Product, tenant_id: tenant.id, sku: product_data.sku) do
    nil ->
      product =
        %Product{}
        |> Product.changeset(Map.put(product_data, :tenant_id, tenant.id))
        |> Repo.insert!()

      category_emoji =
        case product.category do
          "goods" -> "📦"
          "materials" -> "🔧"
          "produced" -> "🏭"
          "services" -> "⚙️"
          _ -> "❓"
        end

      IO.puts("  ✓ Product #{category_emoji} #{product.sku} - #{product.name}")

    _existing ->
      IO.puts("  - Product #{product_data.sku} already exists")
  end
end

IO.puts("\n✅ Seed data completed successfully!")
IO.puts("\n📊 Summary:")
IO.puts("  - Tenant: #{tenant.name}")
IO.puts("  - Accounts: #{length(accounts_data)} chart of accounts entries")
IO.puts("  - Warehouses: #{length(warehouses_data)} warehouses")
IO.puts("  - Contacts: #{length(contacts_data)} contacts (customers & suppliers)")
IO.puts("  - Products: #{length(products_data)} products")
IO.puts("    - 📦 Стоки (Goods): 4")
IO.puts("    - 🔧 Материали (Materials): 5")
IO.puts("    - 🏭 Произведена продукция (Produced): 4")
IO.puts("    - ⚙️ Услуги (Services): 5")
IO.puts("\n🚀 Ready to use! Start the server with: mix phx.server")

# 6. Create Users and Permissions
IO.puts("\n🔐 Creating users and permissions...")

alias CyberCore.Accounts
alias CyberCore.Guardian

# Create Permissions
permissions = [
  # Contacts
  %{name: "contacts.create", description: "Create contacts"},
  %{name: "contacts.read", description: "Read contacts"},
  %{name: "contacts.update", description: "Update contacts"},
  %{name: "contacts.delete", description: "Delete contacts"},

  # Products
  %{name: "products.create", description: "Create products"},
  %{name: "products.read", description: "Read products"},
  %{name: "products.update", description: "Update products"},
  %{name: "products.delete", description: "Delete products"},

  # Invoices
  %{name: "invoices.create", description: "Create invoices"},
  %{name: "invoices.read", description: "Read invoices"},
  %{name: "invoices.update", description: "Update invoices"},
  %{name: "invoices.delete", description: "Delete invoices"}
]

for p_attrs <- permissions do
  case Guardian.create_permission(p_attrs) do
    {:ok, _} -> IO.puts("  ✓ Permission created: #{p_attrs.name}")
    {:error, _} -> IO.puts("  - Permission already exists: #{p_attrs.name}")
  end
end

# Grant Permissions to Roles
# Admin can do everything
for p <- permissions, do: Guardian.grant("admin", p.name)

# User can read and create, but not delete
Guardian.grant("user", "contacts.read")
Guardian.grant("user", "contacts.create")
Guardian.grant("user", "contacts.update")
Guardian.grant("user", "products.read")
Guardian.grant("user", "products.create")
Guardian.grant("user", "invoices.read")
Guardian.grant("user", "invoices.create")

# Observer can only read
Guardian.grant("observer", "contacts.read")
Guardian.grant("observer", "products.read")
Guardian.grant("observer", "invoices.read")

IO.puts("\n✓ Permissions granted to roles.")

# Create Users
# Superadmin
case Repo.get_by(Accounts.User, email: "superadmin@example.com") do
  nil ->
    Accounts.register_user(%{
      tenant_id: tenant.id,
      email: "superadmin@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Super",
      last_name: "Admin",
      role: "superadmin"
    })

    IO.puts("  ✓ Superadmin created: superadmin@example.com")

  _ ->
    IO.puts("  - Superadmin already exists: superadmin@example.com")
end

# Admin for the demo tenant
case Repo.get_by(Accounts.User, email: "admin@demo.com") do
  nil ->
    {:ok, admin_user} =
      Accounts.register_user(%{
        tenant_id: tenant.id,
        email: "admin@demo.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Demo",
        last_name: "Admin",
        # Default role on users table
        role: "admin"
      })

    # Grant explicit admin role on the tenant
    Accounts.grant_tenant_access(admin_user, tenant, "admin")
    IO.puts("  ✓ Admin created: admin@demo.com")

  _ ->
    IO.puts("  - Admin already exists: admin@demo.com")
end

# User (Accountant) for the demo tenant
case Repo.get_by(Accounts.User, email: "user@demo.com") do
  nil ->
    {:ok, user_user} =
      Accounts.register_user(%{
        tenant_id: tenant.id,
        email: "user@demo.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Demo",
        last_name: "User",
        role: "user"
      })

    Accounts.grant_tenant_access(user_user, tenant, "user")
    IO.puts("  ✓ User created: user@demo.com")

  _ ->
    IO.puts("  - User already exists: user@demo.com")
end

# Observer for the demo tenant
case Repo.get_by(Accounts.User, email: "observer@demo.com") do
  nil ->
    {:ok, observer_user} =
      Accounts.register_user(%{
        tenant_id: tenant.id,
        email: "observer@demo.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Demo",
        last_name: "Observer",
        role: "observer"
      })

    Accounts.grant_tenant_access(observer_user, tenant, "observer")
    IO.puts("  ✓ Observer created: observer@demo.com")

  _ ->
    IO.puts("  - Observer already exists: observer@demo.com")
end

IO.puts("\n✅ Users and permissions seeded successfully!")

# 7. Create OSS VAT Rates
IO.puts("\n🇪🇺 Creating OSS VAT rates...")

oss_vat_rates_data = [
  %{country_code: "AT", country_name: "Австрия", rate: Decimal.new("20")},
  %{country_code: "BE", country_name: "Белгия", rate: Decimal.new("21")},
  %{country_code: "BG", country_name: "България", rate: Decimal.new("20")},
  %{country_code: "HR", country_name: "Хърватия", rate: Decimal.new("25")},
  %{country_code: "CY", country_name: "Кипър", rate: Decimal.new("19")},
  %{country_code: "CZ", country_name: "Чехия", rate: Decimal.new("21")},
  %{country_code: "DK", country_name: "Дания", rate: Decimal.new("25")},
  # From July 2025
  %{country_code: "EE", country_name: "Естония", rate: Decimal.new("24")},
  %{country_code: "FI", country_name: "Финландия", rate: Decimal.new("25.5")},
  %{country_code: "FR", country_name: "Франция", rate: Decimal.new("20")},
  %{country_code: "DE", country_name: "Германия", rate: Decimal.new("19")},
  %{country_code: "GR", country_name: "Гърция", rate: Decimal.new("24")},
  %{country_code: "HU", country_name: "Унгария", rate: Decimal.new("27")},
  %{country_code: "IE", country_name: "Ирландия", rate: Decimal.new("23")},
  %{country_code: "IT", country_name: "Италия", rate: Decimal.new("22")},
  %{country_code: "LV", country_name: "Латвия", rate: Decimal.new("21")},
  %{country_code: "LT", country_name: "Литва", rate: Decimal.new("21")},
  %{country_code: "LU", country_name: "Люксембург", rate: Decimal.new("17")},
  %{country_code: "MT", country_name: "Малта", rate: Decimal.new("18")},
  %{country_code: "NL", country_name: "Нидерландия", rate: Decimal.new("21")},
  %{country_code: "PL", country_name: "Полша", rate: Decimal.new("23")},
  %{country_code: "PT", country_name: "Португалия", rate: Decimal.new("23")},
  # From August 2025
  %{country_code: "RO", country_name: "Румъния", rate: Decimal.new("21")},
  # From Jan 2025
  %{country_code: "SK", country_name: "Словакия", rate: Decimal.new("23")},
  %{country_code: "SI", country_name: "Словения", rate: Decimal.new("22")},
  %{country_code: "ES", country_name: "Испания", rate: Decimal.new("21")},
  %{country_code: "SE", country_name: "Швеция", rate: Decimal.new("25")}
]

for rate_data <- oss_vat_rates_data do
  case Repo.get(OssVatRate, rate_data.country_code) do
    nil ->
      %OssVatRate{}
      |> OssVatRate.changeset(rate_data)
      |> Repo.insert!()

      IO.puts("  ✓ OSS VAT Rate for #{rate_data.country_name} created.")

    existing ->
      existing
      |> OssVatRate.changeset(rate_data)
      |> Repo.update!()

      IO.puts("  - OSS VAT Rate for #{rate_data.country_name} updated.")
  end
end

IO.puts("\n✅ Seed data completed successfully!")
IO.puts("\n📊 Summary:")
IO.puts("  - Tenant: #{tenant.name}")
IO.puts("  - Accounts: #{length(accounts_data)} chart of accounts entries")
IO.puts("  - Warehouses: #{length(warehouses_data)} warehouses")
IO.puts("  - Contacts: #{length(contacts_data)} contacts (customers & suppliers)")
IO.puts("  - Products: #{length(products_data)} products")
IO.puts("    - 📦 Стоки (Goods): 4")
IO.puts("    - 🔧 Материали (Materials): 5")
IO.puts("    - 🏭 Произведена продукция (Produced): 4")
IO.puts("    - ⚙️ Услуги (Services): 5")
IO.puts("  - OSS VAT Rates: #{length(oss_vat_rates_data)} countries")
IO.puts("\n🚀 Ready to use! Start the server with: mix phx.server")
