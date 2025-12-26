defmodule CyberWeb.LoginLive do
  use Phoenix.LiveView,
    layout: {CyberWeb.Layouts, :root}

  import Phoenix.Component

  @impl true
  def mount(_params, session, socket) do
    case session["user_id"] do
      nil ->
        {:ok, assign(socket, :page_title, "Вход")}

      _user_id ->
        {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex items-center justify-center p-4 relative overflow-hidden">
      <!-- Animated background grid -->
      <div class="absolute inset-0 opacity-20">
        <div class="absolute inset-0" style="background-image: linear-gradient(rgba(0, 255, 136, 0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(0, 255, 136, 0.1) 1px, transparent 1px); background-size: 50px 50px;"></div>
      </div>

      <!-- Glowing orbs -->
      <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-emerald-500/20 rounded-full blur-3xl animate-pulse"></div>
      <div class="absolute bottom-1/4 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl animate-pulse" style="animation-delay: 1s;"></div>

      <div class="relative z-10 w-full max-w-md">
        <!-- Logo/Title -->
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-gradient-to-br from-emerald-400 to-cyan-500 mb-4 shadow-lg shadow-emerald-500/30">
            <svg class="w-10 h-10 text-gray-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-400 tracking-wider">
            CYBER ERP
          </h1>
          <p class="mt-2 text-emerald-500/70 text-sm font-mono">[ SECURE ACCESS TERMINAL ]</p>
        </div>

        <!-- Login Card -->
        <div class="bg-gray-800/50 backdrop-blur-xl rounded-2xl border border-emerald-500/20 shadow-2xl shadow-emerald-500/10 p-8">
          <div class="flex items-center gap-2 mb-6 pb-4 border-b border-emerald-500/20">
            <div class="w-3 h-3 rounded-full bg-red-500"></div>
            <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
            <div class="w-3 h-3 rounded-full bg-emerald-500"></div>
            <span class="ml-2 text-emerald-500/50 text-xs font-mono">auth@cybererp:~$</span>
          </div>

          <form action="/login" method="post" class="space-y-6">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="email" class="block text-sm font-mono text-emerald-400 mb-2">
                <span class="text-emerald-600">></span> EMAIL_ADDRESS
              </label>
              <input
                type="email"
                id="email"
                name="email"
                required
                autocomplete="email"
                placeholder="user@domain.com"
                class="w-full px-4 py-3 bg-gray-900/50 border border-emerald-500/30 rounded-lg text-emerald-100 placeholder-emerald-700 focus:outline-none focus:border-emerald-400 focus:ring-1 focus:ring-emerald-400 font-mono transition-all"
              />
            </div>

            <div>
              <label for="password" class="block text-sm font-mono text-emerald-400 mb-2">
                <span class="text-emerald-600">></span> PASSWORD
              </label>
              <input
                type="password"
                id="password"
                name="password"
                required
                autocomplete="current-password"
                placeholder="••••••••••••"
                class="w-full px-4 py-3 bg-gray-900/50 border border-emerald-500/30 rounded-lg text-emerald-100 placeholder-emerald-700 focus:outline-none focus:border-emerald-400 focus:ring-1 focus:ring-emerald-400 font-mono transition-all"
              />
            </div>

            <button
              type="submit"
              class="w-full py-3 px-4 bg-gradient-to-r from-emerald-500 to-cyan-500 text-gray-900 font-bold rounded-lg hover:from-emerald-400 hover:to-cyan-400 focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:ring-offset-2 focus:ring-offset-gray-900 transition-all duration-200 shadow-lg shadow-emerald-500/30 font-mono tracking-wider"
            >
              AUTHENTICATE
            </button>
          </form>

          <div class="mt-6 text-center">
            <a href="/forgot-password" class="text-sm text-emerald-500/70 hover:text-emerald-400 font-mono transition-colors">
              [ Забравена парола? ]
            </a>
          </div>
        </div>

        <!-- Footer -->
        <div class="mt-6 text-center">
          <p class="text-emerald-600/50 text-xs font-mono">
            <span class="inline-block w-2 h-2 bg-emerald-500 rounded-full animate-pulse mr-2"></span>
            SYSTEM ONLINE
          </p>
        </div>
      </div>
    </div>
    """
  end
end
