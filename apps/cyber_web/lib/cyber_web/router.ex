defmodule CyberWeb.Router do
  use CyberWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CyberWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CyberWeb.Plugs.SetCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CyberWeb.Plugs.FetchTenant
    plug CyberWeb.Plugs.Authenticate
  end

  pipeline :contacts_create_auth do
    plug CyberWeb.Plugs.Authorize, "contacts.create"
  end

  # Public routes (no authentication required)
  scope "/", CyberWeb do
    pipe_through :browser

    live "/login", LoginLive, :index
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    # Password reset
    live "/forgot-password", ForgotPasswordLive, :index
    live "/reset-password/:token", ResetPasswordLive, :index
  end

  # Protected routes (authentication required)
  scope "/", CyberWeb do
    pipe_through :browser

    live "/", DashboardLive, :index

    # Products (Артикули)
    live "/products", ProductLive.Index, :index
    live "/products/new", ProductLive.Index, :new
    live "/products/:id/edit", ProductLive.Index, :edit

    # Warehouses
    live "/warehouses", Warehouse.WarehouseLive, :index
    live "/warehouses/new", Warehouse.WarehouseLive, :new
    live "/warehouses/:id/edit", Warehouse.WarehouseLive, :edit

    # Purchases
    live "/purchase-orders", PurchaseOrderLive.Index, :index
    live "/purchase-orders/new", PurchaseOrderLive.Index, :new
    live "/purchase-orders/:id/edit", PurchaseOrderLive.Index, :edit

    live "/supplier-invoices", SupplierInvoiceLive.Index, :index
    live "/supplier-invoices/new", SupplierInvoiceLive.Index, :new
    live "/supplier-invoices/:id/edit", SupplierInvoiceLive.Index, :edit

    # Invoices
    live "/invoices", InvoiceLive.Index, :index
    live "/invoices/new", InvoiceLive.Index, :new
    live "/invoices/:id/edit", InvoiceLive.Index, :edit
    live "/invoices/:id", InvoiceLive.Index, :show

    # Warehouse
    live "/warehouse", Warehouse.DashboardLive, :index
    # The following routes are not yet implemented, but are added for completeness
    # live "/warehouses", CyberWeb.WarehouseCrudLive.Index, :index
    # live "/stock-levels", StockLevelLive.Index, :index
    live "/stock-movements", StockMovementLive.Index, :index
    live "/stock-documents", StockDocumentLive.Index, :index
    live "/goods-receipts/new", GoodsReceiptLive.FormComponent, :new
    live "/goods-issues/new", GoodsIssueLive.FormComponent, :new
    live "/stock-transfers/new", StockTransferLive.FormComponent, :new

    # Stock Adjustments (Scrap, Shortage, Surplus)
    live "/stock-adjustments/:type", StockAdjustmentLive.FormComponent, :new

    # Inventory Count (Инвентаризация)
    live "/inventory-counts", InventoryCountLive.Index, :index
    live "/inventory-counts/new", InventoryCountLive.Index, :new
    live "/inventory-counts/:id", InventoryCountLive.Index, :show
    # Алтернативен път
    live "/stock-counts", InventoryCountLive.Index, :index
    live "/stock-counts/new", InventoryCountLive.Index, :new

    # Sales & POS
    live "/sales", SaleLive.Index, :index
    live "/sales/:id", SaleLive.Index, :show
    live "/pos", PosLive.Index, :index

    # Price Lists
    live "/price-lists", PriceListLive.Index, :index
    live "/price-lists/new", PriceListLive.Index, :new
    live "/price-lists/:id/edit", PriceListLive.Index, :edit
    live "/price-lists/:id", PriceListLive.Show, :show

    # Bank accounts (за демонстрация)
    live "/bank_accounts", BankAccountLive.Index, :index
    live "/stock-levels", StockLevelLive.Index, :index

    # Manufacturing
    live "/work-centers", WorkCenterLive.Index, :index
    live "/work-centers/new", WorkCenterLive.Index, :new
    live "/work-centers/:id/edit", WorkCenterLive.Index, :edit

    live "/tech-cards", TechCardLive.Index, :index
    live "/tech-cards/new", TechCardLive.Index, :new
    live "/tech-cards/:id/edit", TechCardLive.Index, :edit

    live "/recipes", RecipeLive.Index, :index
    live "/recipes/new", RecipeLive.Index, :new
    live "/recipes/:id/edit", RecipeLive.Index, :edit

    live "/production-orders", ProductionOrderLive.Index, :index
    live "/production-orders/new", ProductionOrderLive.Index, :new
    live "/production-orders/:id/edit", ProductionOrderLive.Index, :edit
    live "/production-report", ProductionReportLive.Index, :index

    # Currencies and Exchange Rates
    live "/currencies", CurrencyLive.Index, :index
    live "/exchange-rates", ExchangeRateLive.Index, :index

    # Accounting
    live "/journal-entries", JournalEntryLive.Index, :index
    live "/journal-entries/new", JournalEntryLive.Index, :new
    live "/journal-entries/:id", JournalEntryLive.Index, :show
    live "/trial-balance", TrialBalanceLive.Index, :index
    live "/accounts", AccountLive.Index, :index
    live "/accounts/new", AccountLive.Index, :new
    live "/accounts/:id/edit", AccountLive.Index, :edit

    # VAT (ДДС)
    live "/vat/return", VatReturnLive.Index, :index
    live "/vat/sales-register", VatSalesRegisterLive.Index, :index
    live "/vat/purchase-register", VatPurchaseRegisterLive.Index, :index
    live "/vat/purchase-register/new", VatPurchaseRegisterLive.Index, :new
    live "/vat/purchase-register/:id/edit", VatPurchaseRegisterLive.Index, :edit
    live "/vat/oss-report", OssReportLive.Index, :index

    # Intrastat
    live "/intrastat", IntrastatLive.Index, :index

    # SAF-T (Standard Audit File for Tax)
    live "/saft", SaftLive.Index, :index

    # Fixed Assets (ДМА)
    live "/fixed-assets", FixedAssetLive.Index, :index
    live "/fixed-assets/new", FixedAssetLive.Index, :new
    live "/fixed-assets/:id/edit", FixedAssetLive.Index, :edit
    live "/fixed-assets/:id", FixedAssetLive.Index, :show
    live "/fixed-assets/:id/schedule", FixedAssetLive.Index, :schedule
    live "/fixed-assets/:id/increase-value", FixedAssetLive.Index, :increase_value

    # Contacts (Контакти)
    live "/contacts", ContactLive.Index, :index
    live "/contacts/new", ContactLive.Index, :new
    live "/contacts/:id/edit", ContactLive.Index, :edit

    # Bank (Банки)
    live "/bank-profiles", BankProfileLive.Index, :index
    live "/bank-profiles/new", BankProfileLive.Index, :new
    live "/bank-profiles/:id/edit", BankProfileLive.Index, :edit
    live "/bank-imports", BankImportLive.Index, :index
    live "/bank-transactions", BankTransactionLive.Index, :index

    # Documents & AI Processing
    live "/documents/upload", DocumentUploadLive.Index, :index
    live "/extracted-invoices", ExtractedInvoiceLive.Index, :index
    live "/extracted-invoices/:id", ExtractedInvoiceLive.Index, :show

    # Settings
    live "/settings", SettingsLive.Index, :index
    live "/nomenclatures", NomenclatureLive.Index, :index

    # Profile
    live "/profile", ProfileLive.Index, :index

    # Tenants (Фирми)
    live "/tenants", TenantLive.Index, :index
    live "/tenants/new", TenantLive.Index, :new
    live "/tenants/:id/edit", TenantLive.Index, :edit

    # Permissions
    live "/permissions", PermissionLive.Index, :index

    # Opening Balances (Начални салда)
    live "/opening-balances", OpeningBalancesLive.Index, :index
  end

  scope "/inventory", CyberWeb do
    pipe_through [:browser, :require_authenticated_user, :require_active_tenant]

    live "/", InventoryLive.Index, :index
    live "/new", InventoryLive.Index, :new
    live "/:id/edit", InventoryLive.Index, :edit
    
    live "/opening-balances", InventoryLive.OpeningBalances, :index

    live "/products", InventoryLive.Products, :index
    live "/products/new", InventoryLive.Products, :new
    live "/products/:id", InventoryLive.Products, :show
    live "/products/:id/edit", InventoryLive.Products, :edit

    live "/warehouses", InventoryLive.Warehouses, :index
    live "/warehouses/new", InventoryLive.Warehouses, :new
    live "/warehouses/:id", InventoryLive.Warehouses, :show
    live "/warehouses/:id/edit", InventoryLive.Warehouses, :edit
  end
  
  scope "/accounting", CyberWeb do
    pipe_through [:browser, :require_authenticated_user, :require_active_tenant]
    
    live "/", AccountingLive.Index, :index
    live "/opening-balances", InventoryLive.OpeningBalances, :index
    
    live "/accounts", AccountingLive.Accounts, :index
    live "/accounts/new", AccountingLive.Accounts, :new
    live "/accounts/:id/edit", AccountingLive.Accounts, :edit

    live "/journal-entries", AccountingLive.JournalEntries, :index
    live "/journal-entries/new", AccountingLive.JournalEntries, :new
    live "/journal-entries/:id/edit", AccountingLive.JournalEntries, :edit

    live "/fixed-assets", AccountingLive.FixedAssets, :index
    live "/fixed-assets/new", AccountingLive.FixedAssets, :new
    live "/fixed-assets/:id/edit", AccountingLive.FixedAssets, :edit
    live "/fixed-assets/:id", AccountingLive.FixedAssets, :show
    live "/fixed-assets/:id/schedule", AccountingLive.FixedAssets, :schedule
    live "/fixed-assets/:id/increase-value", AccountingLive.FixedAssets, :increase_value

    live "/trial-balance", AccountingLive.TrialBalance, :index
  end

  scope "/api", CyberWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    get "/auth/me", AuthController, :me

    resources "/contacts", ContactController, except: [:new, :edit, :create]
    post "/contacts", ContactController, :create, pipe_through: [:api, :contacts_create_auth]
    resources "/products", ProductController, except: [:new, :edit]
    resources "/sales", SaleController, except: [:new, :edit]

    # Inventory module routes
    resources "/warehouses", WarehouseController, except: [:new, :edit]

    # Sales module routes
    resources "/invoices", InvoiceController, except: [:new, :edit]
    resources "/quotations", QuotationController, except: [:new, :edit]
    post "/quotations/:id/convert", QuotationController, :convert

    # Purchase module routes
    resources "/purchase_orders", PurchaseOrderController, except: [:new, :edit]

    # Bank module routes
    resources "/bank_accounts", BankAccountController, except: [:new, :edit]
    resources "/bank_transactions", BankTransactionController, except: [:new, :edit]
    post "/bank_transactions/:id/reconcile", BankTransactionController, :reconcile

    # Accounting module routes
    scope "/accounting", Accounting, as: :accounting do
      resources "/accounts", AccountController, except: [:new, :edit]
      resources "/journal-entries", JournalEntryController, except: [:new, :edit]

      # Fixed Assets (ДМА) with extended functionality
      resources "/assets", AssetController, except: [:new, :edit] do
        post "/increase-value", AssetController, :increase_value
        get "/transactions", AssetController, :transactions
      end

      # Asset statistics and exports
      get "/assets-statistics", AssetController, :statistics
      get "/assets-export-saft/:year", AssetController, :export_saft_annual
      post "/assets-prepare-year/:year", AssetController, :prepare_year_beginning

      resources "/financial-accounts", FinancialAccountController, except: [:new, :edit]

      resources "/financial-transactions", FinancialTransactionController,
        only: [:index, :create, :update, :delete]
    end
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:cyber_web, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def require_active_tenant(conn, _opts) do
    if conn.assigns[:current_tenant] do
      conn
    else
      conn
      |> put_flash(:error, "Моля, изберете фирма.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
