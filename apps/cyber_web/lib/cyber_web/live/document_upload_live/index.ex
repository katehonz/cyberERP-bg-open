defmodule CyberWeb.DocumentUploadLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.DocumentProcessing
  alias CyberCore.Settings

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = 1

    # Проверка дали има настроен Azure Form Recognizer
    azure_enabled = Settings.integration_enabled?(tenant_id, "azure_form_recognizer")

    socket =
      socket
      |> assign(:tenant_id, tenant_id)
      |> assign(:page_title, "Обработка на документи")
      |> assign(:azure_enabled, azure_enabled)
      |> assign(:uploaded_files, [])
      |> assign(:processing, false)
      |> assign(:processing_results, [])
      |> assign(:invoice_type, "purchase")
      |> assign(:upload_progress, %{})
      |> assign(:overall_progress, 0)
      |> assign(:overall_upload_progress, 0)
      |> allow_upload(:documents,
        accept: ~w(.pdf),
        max_entries: 10,
        max_file_size: 10_000_000,
        progress: &handle_upload_progress/3
      )

    {:ok, socket}
  end

  def handle_upload_progress(:documents, _entry, socket) do
    {:noreply, assign_overall_upload_progress(socket)}
  end

  defp assign_overall_upload_progress(socket) do
    entries = socket.assigns.uploads.documents.entries
    total_files = length(entries)

    if total_files > 0 do
      total_progress =
        Enum.reduce(entries, 0, fn entry, acc ->
          acc + entry.progress
        end)

      overall_progress = trunc(total_progress / total_files)
      assign(socket, :overall_upload_progress, overall_progress)
    else
      assign(socket, :overall_upload_progress, 0)
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  @impl true
  def handle_event("select-invoice-type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :invoice_type, type)}
  end

  @impl true
  def handle_event("process-documents", _params, socket) do
    if !socket.assigns.azure_enabled do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Azure Form Recognizer не е конфигуриран. Моля настройте в /settings"
       )}
    else
      entries = socket.assigns.uploads.documents.entries

      # Initialize progress for all entries
      progress_map =
        Enum.into(entries, %{}, fn entry ->
          {entry.ref, :processing}
        end)

      socket =
        socket
        |> assign(:processing, true)
        |> assign(:upload_progress, progress_map)

      # Start async processing
      parent_pid = self()
      for entry <- entries do
        Task.async(fn ->
          process_entry(socket, entry, parent_pid)
        end)
      end

      {:noreply, socket}
    end
  end

  # This function will run in a separate process
  defp process_entry(socket, entry, parent_pid) do
    # This is a simplified version of consume_uploaded_entry
    case File.read(entry.path) do
      {:ok, pdf_binary} ->
        uploads_dir = Path.join([:code.priv_dir(:cyber_web), "static", "uploads", "documents"])
        File.mkdir_p!(uploads_dir)
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        unique_filename = "#{timestamp}_#{entry.client_name}"
        local_path = Path.join(uploads_dir, unique_filename)
        File.write!(local_path, pdf_binary)

        case DocumentProcessing.DocumentProcessor.process_single_pdf(
               socket.assigns.tenant_id,
               pdf_binary,
               entry.client_name,
               invoice_type: socket.assigns.invoice_type,
               local_path: "/uploads/documents/#{unique_filename}"
             ) do
          {:ok, result} ->
            send(parent_pid, {:upload_progress, entry.ref, {:ok, result}})

          {:error, reason} ->
            send(parent_pid, {:upload_progress, entry.ref, {:error, reason}})
        end
      {:error, reason} ->
        send(parent_pid, {:upload_progress, entry.ref, {:error, reason}})
    end
  end

  @impl true
  def handle_info({:upload_progress, ref, result}, socket) do
    # Update progress map
    new_progress = Map.put(socket.assigns.upload_progress, ref, result)
    socket = assign(socket, :upload_progress, new_progress)
    socket = assign_overall_progress(socket)

    # Check if all uploads are done
    if Enum.all?(new_progress, fn {_, v} -> v != :processing end) do
      # All done
      processing_results =
        Enum.map(new_progress, fn {ref, res} ->
          entry = Enum.find(socket.assigns.uploads.documents.entries, &(&1.ref == ref))
          %{name: entry.client_name, status: elem(res, 0), result: elem(res, 1)}
        end)

      socket =
        socket
        |> assign(:processing, false)
        |> assign(:processing_results, processing_results)
        |> put_flash(:info, "Обработката приключи")

      {:noreply, socket}
    else
      # Still processing
      {:noreply, socket |> assign_overall_progress()}
    end
  end

  defp assign_overall_progress(socket) do
    total_files = length(socket.assigns.uploads.documents.entries)
    if total_files > 0 do
      processed_files =
        Enum.count(socket.assigns.upload_progress, fn {_, v} -> v != :processing end)

      overall_progress = trunc(processed_files / total_files * 100)
      assign(socket, :overall_progress, overall_progress)
    else
      assign(socket, :overall_progress, 0)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">
            Сканиране на документи
          </h1>
          <p class="mt-2 text-sm text-gray-700">
            Качете PDF фактури за автоматично извличане на данни чрез Azure Form Recognizer
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <!-- Избор на тип фактура -->
          <div class="inline-flex rounded-md shadow-sm" role="group">
            <button
              type="button"
              phx-click="select-invoice-type"
              phx-value-type="purchase"
              class={"px-4 py-2 text-sm font-medium rounded-l-lg border #{if @invoice_type == "purchase", do: "bg-blue-600 text-white border-blue-600", else: "bg-white text-gray-900 border-gray-300 hover:bg-gray-50"}"}
            >
              Покупки
            </button>
            <button
              type="button"
              phx-click="select-invoice-type"
              phx-value-type="sales"
              class={"px-4 py-2 text-sm font-medium rounded-r-lg border-t border-r border-b #{if @invoice_type == "sales", do: "bg-blue-600 text-white border-blue-600", else: "bg-white text-gray-900 border-gray-300 hover:bg-gray-50"}"}
            >
              Продажби
            </button>
          </div>
        </div>
      </div>

      <!-- Проверка за конфигурация -->
      <%= if !@azure_enabled do %>
        <div class="mt-6 rounded-md bg-yellow-50 p-4 border border-yellow-200">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg
                class="h-5 w-5 text-yellow-400"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">Azure Form Recognizer не е настроен</h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p>
                  За да използвате автоматичното извличане на данни, моля
                  <.link href={~p"/settings"} class="underline font-semibold">
                    конфигурирайте Azure Form Recognizer в Настройки
                  </.link>
                </p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Upload Zone -->
      <div class="mt-8">
        <form
          id="upload-form"
          phx-submit="process-documents"
          phx-change="validate"
          class="space-y-6"
        >
          <div
            class="relative block w-full rounded-lg border-2 border-dashed border-gray-300 p-12 text-center hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            phx-drop-target={@uploads.documents.ref}
          >
            <svg
              class="mx-auto h-12 w-12 text-gray-400"
              stroke="currentColor"
              fill="none"
              viewBox="0 0 48 48"
              aria-hidden="true"
            >
              <path
                d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
            <h3 class="mt-2 text-sm font-semibold text-gray-900">Качете PDF фактури</h3>
            <p class="mt-1 text-sm text-gray-500">
              Drag and drop или кликнете за избор на файлове
            </p>
            <p class="mt-1 text-xs text-gray-500">
              PDF файлове до 10MB, максимум 10 файла
            </p>

            <div class="mt-6">
              <.live_file_input upload={@uploads.documents} class="sr-only" />
              <label
                for={@uploads.documents.ref}
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 cursor-pointer"
              >
                Изберете файлове
              </label>
            </div>
          </div>

          <!-- Списък с качени файлове -->
          <%= if @uploads.documents.entries != [] do %>
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <%= if @overall_upload_progress > 0 && @overall_upload_progress < 100 do %>
                  <div class="mb-4">
                    <h3 class="text-base font-semibold leading-6 text-gray-900 mb-2">
                      Общ напредък на качване: <%= @overall_upload_progress %>%
                    </h3>
                    <div class="w-full bg-gray-200 rounded-full h-2.5">
                      <div
                        class="bg-blue-600 h-2.5 rounded-full transition-all duration-300"
                        style={"width: #{@overall_upload_progress}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= if @processing && @overall_progress > 0 do %>
                  <div class="mb-4">
                    <h3 class="text-base font-semibold leading-6 text-gray-900 mb-2">
                      Общ напредък на обработка: <%= @overall_progress %>%
                    </h3>
                    <div class="w-full bg-gray-200 rounded-full h-2.5">
                      <div
                        class="bg-indigo-600 h-2.5 rounded-full transition-all duration-300"
                        style={"width: #{@overall_progress}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>
                <h3 class="text-base font-semibold leading-6 text-gray-900 mb-4">
                  Избрани файлове (<%= length(@uploads.documents.entries) %>)
                </h3>

                <ul role="list" class="divide-y divide-gray-200">
                  <%= for entry <- @uploads.documents.entries do %>
                    <li class="py-3">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center min-w-0">
                          <svg
                            class="h-8 w-8 text-red-600 flex-shrink-0"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                          >
                            <path
                              fill-rule="evenodd"
                              d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"
                              clip-rule="evenodd"
                            />
                          </svg>
                          <div class="ml-3 min-w-0 flex-1">
                            <p class="text-sm font-medium text-gray-900 truncate">
                              <%= entry.client_name %>
                            </p>
                            <p class="text-sm text-gray-500">
                              <%= Float.round(entry.client_size / 1024 / 1024, 2) %> MB
                            </p>
                            <!-- Progress bar and status -->
                            <div class="mt-2">
                              <%= case @upload_progress[entry.ref] do %>
                                <% :processing -> %>
                                  <div class="flex items-center text-sm text-blue-600">
                                    <svg class="animate-spin h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                    Обработка...
                                  </div>
                                <% {:ok, _} -> %>
                                  <div class="flex items-center text-sm text-green-600">
                                    <svg class="h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                                    </svg>
                                    Завършен
                                  </div>
                                <% {:error, reason} -> %>
                                  <div class="flex items-center text-sm text-red-600" title={"#{inspect(reason)}"}>
                                    <svg class="h-4 w-4 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                                    </svg>
                                    Грешка
                                  </div>
                                <% _ -> %>
                                  <div class="w-full bg-gray-200 rounded-full h-2">
                                    <div
                                      class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
                                      style={"width: #{entry.progress}%"}
                                    >
                                    </div>
                                  </div>
                              <% end %>
                            </div>
                          </div>
                        </div>
                        <button
                          type="button"
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                          class="ml-4 flex-shrink-0 text-sm font-medium text-red-600 hover:text-red-500"
                        >
                          Премахни
                        </button>
                      </div>
                    </li>
                  <% end %>
                </ul>

                <!-- Errors -->
                <%= for err <- upload_errors(@uploads.documents) do %>
                  <p class="mt-2 text-sm text-red-600">
                    <%= error_to_string(err) %>
                  </p>
                <% end %>

                <div class="mt-6 flex justify-end">
                  <button
                    type="submit"
                    disabled={@processing || !@azure_enabled}
                    class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <%= if @processing do %>
                      <svg
                        class="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          class="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          stroke-width="4"
                        >
                        </circle>
                        <path
                          class="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        >
                        </path>
                      </svg>
                      Обработва се...
                    <% else %>
                      Обработи с AI
                    <% end %>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </form>
      </div>

      <!-- Резултати от обработката -->
      <%= if @processing_results != [] do %>
        <div class="mt-8 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-base font-semibold leading-6 text-gray-900 mb-4">
              Резултати от обработката
            </h3>

            <ul role="list" class="divide-y divide-gray-200">
              <%= for result <- @processing_results do %>
                <li class="py-3">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <%= if result.status == :success do %>
                        <svg
                          class="h-5 w-5 text-green-500"
                          fill="currentColor"
                          viewBox="0 0 20 20"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      <% else %>
                        <svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                          <path
                            fill-rule="evenodd"
                            d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      <% end %>
                      <div class="ml-3">
                        <p class="text-sm font-medium text-gray-900"><%= result.name %></p>
                        <%= if result.status == :success do %>
                          <p class="text-sm text-green-600">
                            Успешно обработен - Фактура № <%= result.result.extracted_invoice.invoice_number %>
                          </p>
                        <% else %>
                          <p class="text-sm text-red-600"><%= inspect(result.reason) %></p>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </li>
              <% end %>
            </ul>

            <div class="mt-4">
              <.link
                href={~p"/extracted-invoices"}
                class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
              >
                Преглед на извлечените фактури →
              </.link>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Инструкции -->
      <div class="mt-8 bg-blue-50 border border-blue-200 rounded-md p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="h-5 w-5 text-blue-400"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-blue-800">Как работи?</h3>
            <div class="mt-2 text-sm text-blue-700">
              <ol class="list-decimal list-inside space-y-1">
                <li>Качете PDF фактури (до 10 файла едновременно)</li>
                <li>Натиснете "Обработи с AI"</li>
                <li>
                  Azure Form Recognizer автоматично извлича данни (номер, доставчик, суми, ДДС)
                </li>
                <li>Прегледайте и одобрете извлечените данни в "Извлечени фактури"</li>
                <li>След одобрение фактурата се записва в системата</li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Файлът е твърде голям (максимум 10MB)"
  defp error_to_string(:not_accepted), do: "Невалиден файлов формат (само PDF)"
  defp error_to_string(:too_many_files), do: "Твърде много файлове (максимум 10)"
end
