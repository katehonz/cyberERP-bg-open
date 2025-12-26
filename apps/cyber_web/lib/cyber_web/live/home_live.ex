defmodule CyberWeb.HomeLive do
  use CyberWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Welcome")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-4xl font-bold text-zinc-900 mb-4">
        Welcome to Cyber ERP
      </h1>
      <p class="text-lg text-zinc-600 mb-8">
        Enterprise Resource Planning System
      </p>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-12">
        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Contacts</h3>
          <p class="text-zinc-600 mb-4">Manage your customers and suppliers</p>
          <a href="/api/contacts" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>

        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Products</h3>
          <p class="text-zinc-600 mb-4">Catalog and inventory management</p>
          <a href="/api/products" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>

        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Sales</h3>
          <p class="text-zinc-600 mb-4">Track sales and orders</p>
          <a href="/api/sales" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>

        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Accounting</h3>
          <p class="text-zinc-600 mb-4">Financial management and reports</p>
          <a href="/api/accounting/accounts" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>

        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Assets</h3>
          <p class="text-zinc-600 mb-4">Asset tracking and depreciation</p>
          <a href="/api/accounting/assets" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>

        <div class="p-6 bg-white border border-zinc-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
          <h3 class="text-xl font-semibold text-zinc-900 mb-2">Authentication</h3>
          <p class="text-zinc-600 mb-4">User login and registration</p>
          <a href="/api/auth/login" class="text-blue-600 hover:text-blue-800 font-medium">
            View API &rarr;
          </a>
        </div>
      </div>

      <div class="mt-12 p-6 bg-blue-50 border border-blue-200 rounded-lg">
        <h2 class="text-2xl font-semibold text-blue-900 mb-2">API First Design</h2>
        <p class="text-blue-700">
          This application is built with a modern API-first architecture.
          All endpoints are available under <code class="px-2 py-1 bg-blue-100 rounded">/api</code>
        </p>
      </div>
    </div>
    """
  end
end
