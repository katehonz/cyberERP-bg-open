defmodule CyberWeb.ForgotPasswordLive do
  use Phoenix.LiveView,
    layout: {CyberWeb.Layouts, :root}

  import Phoenix.Component

  alias CyberCore.Accounts
  alias CyberCore.Email.{PasswordResetEmail, DynamicMailer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Забравена парола",
       email: "",
       submitted: false,
       loading: false,
       error: nil
     )}
  end

  @impl true
  def handle_event("submit", %{"email" => email}, socket) do
    socket = assign(socket, loading: true, error: nil)

    # Always show success message to prevent email enumeration
    case Accounts.generate_password_reset_token(email) do
      {:ok, user, token} ->
        # Try to send email
        base_url = CyberWeb.Endpoint.url()
        email_struct = PasswordResetEmail.password_reset_email(user, token, base_url)

        # Get first active tenant for SMTP settings (or use user's tenant)
        case DynamicMailer.deliver(user.tenant_id, email_struct) do
          {:ok, _} ->
            {:noreply, assign(socket, submitted: true, loading: false)}

          {:error, :smtp_not_configured} ->
            {:noreply,
             assign(socket,
               loading: false,
               error: "Email услугата не е конфигурирана. Моля свържете се с администратор."
             )}

          {:error, _reason} ->
            {:noreply,
             assign(socket,
               loading: false,
               error: "Грешка при изпращане на email. Моля опитайте отново."
             )}
        end

      {:error, :user_not_found} ->
        # Don't reveal that user doesn't exist - show success anyway
        # This prevents email enumeration attacks
        {:noreply, assign(socket, submitted: true, loading: false)}

      {:error, _} ->
        {:noreply,
         assign(socket, loading: false, error: "Възникна грешка. Моля опитайте отново.")}
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
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-400 tracking-wider">
            CYBER ERP
          </h1>
          <p class="mt-2 text-emerald-500/70 text-sm font-mono">[ PASSWORD RECOVERY ]</p>
        </div>

        <!-- Card -->
        <div class="bg-gray-800/50 backdrop-blur-xl rounded-2xl border border-emerald-500/20 shadow-2xl shadow-emerald-500/10 p-8">
          <div class="flex items-center gap-2 mb-6 pb-4 border-b border-emerald-500/20">
            <div class="w-3 h-3 rounded-full bg-red-500"></div>
            <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
            <div class="w-3 h-3 rounded-full bg-emerald-500"></div>
            <span class="ml-2 text-emerald-500/50 text-xs font-mono">recovery@cybererp:~$</span>
          </div>

          <%= if @submitted do %>
            <!-- Success State -->
            <div class="text-center py-8">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-500/20 mb-4">
                <svg class="w-8 h-8 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </div>
              <h2 class="text-xl font-bold text-emerald-400 mb-2">Проверете вашата поща</h2>
              <p class="text-emerald-500/70 text-sm mb-6">
                Ако съществува акаунт с този email адрес, ще получите инструкции за възстановяване на паролата.
              </p>
              <p class="text-emerald-600/50 text-xs font-mono">
                Линкът е валиден 1 час
              </p>
            </div>
          <% else %>
            <!-- Form State -->
            <form phx-submit="submit" class="space-y-6">
              <div>
                <p class="text-emerald-500/70 text-sm mb-4">
                  Въведете вашия email адрес и ще ви изпратим линк за възстановяване на паролата.
                </p>
              </div>

              <%= if @error do %>
                <div class="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
                  <p class="text-red-400 text-sm font-mono"><%= @error %></p>
                </div>
              <% end %>

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
                  disabled={@loading}
                  class="w-full px-4 py-3 bg-gray-900/50 border border-emerald-500/30 rounded-lg text-emerald-100 placeholder-emerald-700 focus:outline-none focus:border-emerald-400 focus:ring-1 focus:ring-emerald-400 font-mono transition-all disabled:opacity-50"
                />
              </div>

              <button
                type="submit"
                disabled={@loading}
                class="w-full py-3 px-4 bg-gradient-to-r from-emerald-500 to-cyan-500 text-gray-900 font-bold rounded-lg hover:from-emerald-400 hover:to-cyan-400 focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:ring-offset-2 focus:ring-offset-gray-900 transition-all duration-200 shadow-lg shadow-emerald-500/30 font-mono tracking-wider disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
              >
                <%= if @loading do %>
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-gray-900" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  PROCESSING...
                <% else %>
                  SEND RECOVERY LINK
                <% end %>
              </button>
            </form>
          <% end %>

          <div class="mt-6 text-center">
            <a href="/login" class="text-sm text-emerald-500/70 hover:text-emerald-400 font-mono transition-colors">
              [ Обратно към вход ]
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
