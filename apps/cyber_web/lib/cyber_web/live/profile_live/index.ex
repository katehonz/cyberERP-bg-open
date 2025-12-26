defmodule CyberWeb.ProfileLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Accounts
  alias CyberCore.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    case user_id do
      nil ->
        {:ok, push_navigate(socket, to: "/login")}

      _ ->
        user = CyberCore.Repo.get!(User, user_id)

        socket =
          socket
          |> assign(:user, user)
          |> assign(:page_title, "Моят профил")
          |> assign(:active_tab, "profile")
          |> assign(:email_form, to_form(%{"email" => user.email}))
          |> assign(:password_form, to_form(%{}))
          |> assign(:email_error, nil)
          |> assign(:email_success, nil)
          |> assign(:password_error, nil)
          |> assign(:password_success, nil)
          |> assign(:email_loading, false)
          |> assign(:password_loading, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("update_email", %{"email" => new_email}, socket) do
    socket = assign(socket, email_loading: true, email_error: nil, email_success: nil)
    user = socket.assigns.user

    case Accounts.update_user(user, %{email: new_email}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:email_form, to_form(%{"email" => updated_user.email}))
         |> assign(:email_success, "Email адресът е променен успешно")
         |> assign(:email_loading, false)}

      {:error, changeset} ->
        error = get_changeset_error(changeset, :email)

        {:noreply,
         socket
         |> assign(:email_error, error)
         |> assign(:email_loading, false)}
    end
  end

  @impl true
  def handle_event("update_password", params, socket) do
    socket = assign(socket, password_loading: true, password_error: nil, password_success: nil)
    user = socket.assigns.user

    current_password = params["current_password"]
    new_password = params["new_password"]
    password_confirmation = params["password_confirmation"]

    # Verify current password
    case Bcrypt.verify_pass(current_password, user.hashed_password) do
      true ->
        # Update password
        case user
             |> User.password_changeset(%{
               password: new_password,
               password_confirmation: password_confirmation
             })
             |> CyberCore.Repo.update() do
          {:ok, _updated_user} ->
            {:noreply,
             socket
             |> assign(:password_form, to_form(%{}))
             |> assign(:password_success, "Паролата е променена успешно")
             |> assign(:password_loading, false)}

          {:error, changeset} ->
            errors = format_changeset_errors(changeset)

            {:noreply,
             socket
             |> assign(:password_error, errors)
             |> assign(:password_loading, false)}
        end

      false ->
        {:noreply,
         socket
         |> assign(:password_error, "Текущата парола е грешна")
         |> assign(:password_loading, false)}
    end
  end

  defp get_changeset_error(changeset, field) do
    case changeset.errors[field] do
      {msg, _} -> msg
      nil -> "Грешка при обновяване"
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {_field, messages} -> Enum.join(messages, ", ") end)
    |> Enum.join("; ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Моят профил</h1>
          <p class="mt-2 text-sm text-gray-700">
            Управление на вашия акаунт и настройки за сигурност
          </p>
        </div>
      </div>

      <!-- User Info Card -->
      <div class="mt-8 bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-16 h-16 rounded-full bg-gradient-to-br from-emerald-400 to-cyan-500 flex items-center justify-center text-white text-2xl font-bold">
                <%= String.first(@user.first_name || @user.email) |> String.upcase() %>
              </div>
            </div>
            <div class="ml-4">
              <h2 class="text-lg font-medium text-gray-900">
                <%= @user.first_name %> <%= @user.last_name %>
              </h2>
              <p class="text-sm text-gray-500"><%= @user.email %></p>
              <p class="text-xs text-gray-400 mt-1">
                Роля: <span class="font-medium"><%= @user.role %></span>
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="mt-8">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="profile"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "profile",
                  do: "border-emerald-500 text-emerald-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              Промяна на Email
            </button>
            <button
              type="button"
              phx-click="switch_tab"
              phx-value-tab="security"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                if(@active_tab == "security",
                  do: "border-emerald-500 text-emerald-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              Смяна на парола
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="mt-8">
        <%= if @active_tab == "profile" do %>
          <!-- Email Change Form -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Промяна на Email адрес</h3>

              <%= if @email_success do %>
                <div class="mb-4 rounded-md bg-green-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-green-800"><%= @email_success %></p>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @email_error do %>
                <div class="mb-4 rounded-md bg-red-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-red-800"><%= @email_error %></p>
                    </div>
                  </div>
                </div>
              <% end %>

              <form phx-submit="update_email" class="space-y-4">
                <div>
                  <label for="email" class="block text-sm font-medium text-gray-700">Нов Email адрес</label>
                  <input
                    type="email"
                    id="email"
                    name="email"
                    value={@user.email}
                    required
                    disabled={@email_loading}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm disabled:opacity-50"
                  />
                </div>

                <div class="flex justify-end">
                  <button
                    type="submit"
                    disabled={@email_loading}
                    class="inline-flex items-center rounded-md border border-transparent bg-emerald-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2 disabled:opacity-50"
                  >
                    <%= if @email_loading do %>
                      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    <% end %>
                    Запази промените
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>

        <%= if @active_tab == "security" do %>
          <!-- Password Change Form -->
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Смяна на парола</h3>

              <%= if @password_success do %>
                <div class="mb-4 rounded-md bg-green-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-green-800"><%= @password_success %></p>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @password_error do %>
                <div class="mb-4 rounded-md bg-red-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm font-medium text-red-800"><%= @password_error %></p>
                    </div>
                  </div>
                </div>
              <% end %>

              <form phx-submit="update_password" class="space-y-4">
                <div>
                  <label for="current_password" class="block text-sm font-medium text-gray-700">Текуща парола</label>
                  <input
                    type="password"
                    id="current_password"
                    name="current_password"
                    required
                    autocomplete="current-password"
                    disabled={@password_loading}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm disabled:opacity-50"
                  />
                </div>

                <div>
                  <label for="new_password" class="block text-sm font-medium text-gray-700">Нова парола</label>
                  <input
                    type="password"
                    id="new_password"
                    name="new_password"
                    required
                    minlength="8"
                    autocomplete="new-password"
                    disabled={@password_loading}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm disabled:opacity-50"
                  />
                  <p class="mt-1 text-xs text-gray-500">Минимум 8 символа</p>
                </div>

                <div>
                  <label for="password_confirmation" class="block text-sm font-medium text-gray-700">Потвърдете новата парола</label>
                  <input
                    type="password"
                    id="password_confirmation"
                    name="password_confirmation"
                    required
                    minlength="8"
                    autocomplete="new-password"
                    disabled={@password_loading}
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm disabled:opacity-50"
                  />
                </div>

                <div class="flex justify-end">
                  <button
                    type="submit"
                    disabled={@password_loading}
                    class="inline-flex items-center rounded-md border border-transparent bg-emerald-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2 disabled:opacity-50"
                  >
                    <%= if @password_loading do %>
                      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    <% end %>
                    Смени паролата
                  </button>
                </div>
              </form>
            </div>
          </div>

          <!-- Security Tips -->
          <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h4 class="text-sm font-medium text-yellow-800">Съвети за сигурност</h4>
                <ul class="mt-2 text-sm text-yellow-700 list-disc list-inside">
                  <li>Използвайте уникална парола за всеки акаунт</li>
                  <li>Комбинирайте букви, цифри и специални символи</li>
                  <li>Никога не споделяйте паролата си с други</li>
                  <li>Сменяйте паролата периодично</li>
                </ul>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
