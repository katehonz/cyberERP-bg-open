defmodule CyberWeb.ResetPasswordLive do
  use Phoenix.LiveView,
    layout: {CyberWeb.Layouts, :root}

  import Phoenix.Component

  alias CyberCore.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.verify_password_reset_token(token) do
      {:ok, user} ->
        {:ok,
         assign(socket,
           page_title: "Нова парола",
           token: token,
           user: user,
           valid_token: true,
           password: "",
           password_confirmation: "",
           loading: false,
           success: false,
           errors: []
         )}

      {:error, :token_expired} ->
        {:ok,
         assign(socket,
           page_title: "Изтекъл линк",
           valid_token: false,
           error_type: :expired
         )}

      {:error, _} ->
        {:ok,
         assign(socket,
           page_title: "Невалиден линк",
           valid_token: false,
           error_type: :invalid
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Невалиден линк",
       valid_token: false,
       error_type: :invalid
     )}
  end

  @impl true
  def handle_event("submit", %{"password" => password, "password_confirmation" => password_confirmation}, socket) do
    socket = assign(socket, loading: true, errors: [])

    case Accounts.reset_password_with_token(socket.assigns.token, password, password_confirmation) do
      {:ok, _user} ->
        {:noreply, assign(socket, success: true, loading: false)}

      {:error, :token_expired} ->
        {:noreply, assign(socket, valid_token: false, error_type: :expired, loading: false)}

      {:error, :invalid_token} ->
        {:noreply, assign(socket, valid_token: false, error_type: :invalid, loading: false)}

      {:error, changeset} ->
        errors = format_errors(changeset)
        {:noreply, assign(socket, errors: errors, loading: false)}
    end
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn msg ->
        case field do
          :password -> "Парола: #{msg}"
          :password_confirmation -> "Потвърждение: #{msg}"
          _ -> "#{field}: #{msg}"
        end
      end)
    end)
  end

  defp format_errors(_), do: ["Възникна грешка. Моля опитайте отново."]

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
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-400 tracking-wider">
            CYBER ERP
          </h1>
          <p class="mt-2 text-emerald-500/70 text-sm font-mono">[ NEW PASSWORD ]</p>
        </div>

        <!-- Card -->
        <div class="bg-gray-800/50 backdrop-blur-xl rounded-2xl border border-emerald-500/20 shadow-2xl shadow-emerald-500/10 p-8">
          <div class="flex items-center gap-2 mb-6 pb-4 border-b border-emerald-500/20">
            <div class="w-3 h-3 rounded-full bg-red-500"></div>
            <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
            <div class="w-3 h-3 rounded-full bg-emerald-500"></div>
            <span class="ml-2 text-emerald-500/50 text-xs font-mono">reset@cybererp:~$</span>
          </div>

          <%= if not @valid_token do %>
            <!-- Invalid/Expired Token State -->
            <div class="text-center py-8">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-500/20 mb-4">
                <svg class="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <%= if @error_type == :expired do %>
                <h2 class="text-xl font-bold text-red-400 mb-2">Линкът е изтекъл</h2>
                <p class="text-emerald-500/70 text-sm mb-6">
                  Този линк за възстановяване на парола е изтекъл.
                  Моля заявете нов линк.
                </p>
              <% else %>
                <h2 class="text-xl font-bold text-red-400 mb-2">Невалиден линк</h2>
                <p class="text-emerald-500/70 text-sm mb-6">
                  Този линк за възстановяване на парола е невалиден или вече е използван.
                </p>
              <% end %>
              <a href="/forgot-password" class="inline-block py-2 px-4 bg-emerald-500/20 border border-emerald-500/30 text-emerald-400 rounded-lg hover:bg-emerald-500/30 transition-colors font-mono text-sm">
                Заяви нов линк
              </a>
            </div>
          <% else %>
            <%= if @success do %>
              <!-- Success State -->
              <div class="text-center py-8">
                <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-500/20 mb-4">
                  <svg class="w-8 h-8 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h2 class="text-xl font-bold text-emerald-400 mb-2">Паролата е променена</h2>
                <p class="text-emerald-500/70 text-sm mb-6">
                  Вашата парола беше успешно променена.
                  Сега можете да влезете с новата си парола.
                </p>
                <a href="/login" class="inline-block py-3 px-8 bg-gradient-to-r from-emerald-500 to-cyan-500 text-gray-900 font-bold rounded-lg hover:from-emerald-400 hover:to-cyan-400 transition-all shadow-lg shadow-emerald-500/30 font-mono tracking-wider">
                  ВХОД
                </a>
              </div>
            <% else %>
              <!-- Form State -->
              <form phx-submit="submit" class="space-y-6">
                <div>
                  <p class="text-emerald-500/70 text-sm mb-4">
                    Въведете новата си парола за акаунта <span class="text-emerald-400 font-mono"><%= @user.email %></span>
                  </p>
                </div>

                <%= if @errors != [] do %>
                  <div class="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
                    <%= for error <- @errors do %>
                      <p class="text-red-400 text-sm font-mono"><%= error %></p>
                    <% end %>
                  </div>
                <% end %>

                <div>
                  <label for="password" class="block text-sm font-mono text-emerald-400 mb-2">
                    <span class="text-emerald-600">></span> NEW_PASSWORD
                  </label>
                  <input
                    type="password"
                    id="password"
                    name="password"
                    required
                    minlength="8"
                    autocomplete="new-password"
                    placeholder="••••••••••••"
                    disabled={@loading}
                    class="w-full px-4 py-3 bg-gray-900/50 border border-emerald-500/30 rounded-lg text-emerald-100 placeholder-emerald-700 focus:outline-none focus:border-emerald-400 focus:ring-1 focus:ring-emerald-400 font-mono transition-all disabled:opacity-50"
                  />
                  <p class="mt-1 text-xs text-emerald-600/50 font-mono">Минимум 8 символа</p>
                </div>

                <div>
                  <label for="password_confirmation" class="block text-sm font-mono text-emerald-400 mb-2">
                    <span class="text-emerald-600">></span> CONFIRM_PASSWORD
                  </label>
                  <input
                    type="password"
                    id="password_confirmation"
                    name="password_confirmation"
                    required
                    minlength="8"
                    autocomplete="new-password"
                    placeholder="••••••••••••"
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
                    SET NEW PASSWORD
                  <% end %>
                </button>
              </form>
            <% end %>
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
