defmodule CyberWeb.WorkCenterLive.Index do
  use CyberWeb, :live_view

  alias CyberCore.Manufacturing
  alias CyberCore.Manufacturing.WorkCenter
  alias Decimal, as: D

  @tenant_id 1

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Работни центрове")
     |> assign(:work_centers, [])
     |> assign(:work_center, nil)
     |> assign(:form, nil)
     |> assign(:filter_active, "all")
     |> assign(:filter_type, "all")
     |> assign(:search_query, "")
     |> load_work_centers()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:work_center, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    work_center = %WorkCenter{
      code: "WC-" <> Integer.to_string(System.unique_integer([:positive])),
      is_active: true,
      center_type: "workstation",
      hourly_rate: D.new(0),
      capacity_per_hour: D.new(1),
      efficiency_percent: D.new(100)
    }

    changeset = Manufacturing.change_work_center(work_center)

    socket
    |> assign(:work_center, work_center)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    work_center = Manufacturing.get_work_center!(@tenant_id, id)
    changeset = Manufacturing.change_work_center(work_center)

    socket
    |> assign(:work_center, work_center)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("filter_active", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:filter_active, status)
     |> load_work_centers()}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> load_work_centers()}
  end

  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_work_centers()}
  end

  def handle_event("validate", %{"work_center" => params}, socket) do
    work_center = socket.assigns.work_center || %WorkCenter{}

    changeset =
      work_center
      |> Manufacturing.change_work_center(normalize_params(params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"work_center" => params}, socket) do
    save_work_center(socket, socket.assigns.live_action, normalize_params(params))
  end

  def handle_event("delete", %{"id" => id}, socket) do
    work_center = Manufacturing.get_work_center!(@tenant_id, id)
    {:ok, _} = Manufacturing.delete_work_center(work_center)

    {:noreply,
     socket
     |> put_flash(:info, "Работният център беше изтрит")
     |> load_work_centers()}
  end

  defp save_work_center(socket, :new, params) do
    case Manufacturing.create_work_center(params) do
      {:ok, _work_center} ->
        {:noreply,
         socket
         |> put_flash(:info, "Работният център беше създаден")
         |> assign(:work_center, nil)
         |> assign(:form, nil)
         |> load_work_centers()
         |> push_patch(to: ~p"/work-centers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_work_center(socket, :edit, params) do
    work_center = Manufacturing.get_work_center!(@tenant_id, socket.assigns.work_center.id)

    case Manufacturing.update_work_center(work_center, params) do
      {:ok, _updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Работният център беше обновен")
         |> load_work_centers()
         |> push_patch(to: ~p"/work-centers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp load_work_centers(socket) do
    opts = build_filter_opts(socket)
    work_centers = Manufacturing.list_work_centers(@tenant_id, opts)
    assign(socket, :work_centers, work_centers)
  end

  defp build_filter_opts(socket) do
    []
    |> maybe_put(:search, socket.assigns.search_query)
    |> maybe_put(:is_active, status_to_bool(socket.assigns.filter_active))
    |> maybe_put(:center_type, type_to_value(socket.assigns.filter_type))
  end

  defp status_to_bool("active"), do: true
  defp status_to_bool("inactive"), do: false
  defp status_to_bool(_), do: nil

  defp type_to_value("all"), do: nil
  defp type_to_value(type), do: type

  defp maybe_put(opts, _key, value) when value in [nil, ""], do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp normalize_params(params) do
    params
    |> Map.put("tenant_id", @tenant_id)
  end

  defp center_type_options do
    [
      {"Работна станция", "workstation"},
      {"Машина", "machine"},
      {"Монтажна линия", "assembly_line"},
      {"Ръчен труд", "manual"},
      {"Външен изпълнител", "outsourced"}
    ]
  end

  defp type_badge("machine"), do: "bg-blue-100 text-blue-800"
  defp type_badge("workstation"), do: "bg-green-100 text-green-800"
  defp type_badge("assembly_line"), do: "bg-purple-100 text-purple-800"
  defp type_badge("manual"), do: "bg-yellow-100 text-yellow-800"
  defp type_badge("outsourced"), do: "bg-orange-100 text-orange-800"
  defp type_badge(_), do: "bg-gray-100 text-gray-800"

  defp status_badge(true), do: "bg-emerald-100 text-emerald-700"
  defp status_badge(false), do: "bg-gray-200 text-gray-600"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Работни центрове</h1>
          <p class="mt-1 text-sm text-gray-600">Управление на машини, станции и производствени линии</p>
        </div>
        <.link
          patch={~p"/work-centers/new"}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700"
        >
          + Нов работен център
        </.link>
      </div>

      <div class="grid gap-4 border border-gray-200 bg-white p-4 shadow-sm sm:grid-cols-4 sm:items-end">
        <div>
          <label class="text-xs font-medium text-gray-500">Статус</label>
          <select name="status" phx-change="filter_active" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_active == "all"}>Всички</option>
            <option value="active" selected={@filter_active == "active"}>Активни</option>
            <option value="inactive" selected={@filter_active == "inactive"}>Неактивни</option>
          </select>
        </div>
        <div>
          <label class="text-xs font-medium text-gray-500">Тип</label>
          <select name="type" phx-change="filter_type" class="mt-1 w-full rounded-md border-gray-300 text-sm">
            <option value="all" selected={@filter_type == "all"}>Всички типове</option>
            <%= for {label, value} <- center_type_options() do %>
              <option value={value} selected={@filter_type == value}><%= label %></option>
            <% end %>
          </select>
        </div>
        <div class="sm:col-span-2">
          <label class="text-xs font-medium text-gray-500">Търсене</label>
          <input
            type="text"
            name="search"
            value={@search_query}
            placeholder="Код или име"
            phx-change="search"
            phx-debounce="300"
            class="mt-1 w-full rounded-md border-gray-300 text-sm"
          />
        </div>
      </div>

      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Код</th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Име</th>
              <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Тип</th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Ставка/час</th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Капацитет/час</th>
              <th class="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Ефективност</th>
              <th class="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wide text-gray-500">Статус</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 bg-white">
            <%= for wc <- @work_centers do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm font-medium text-gray-900"><%= wc.code %></td>
                <td class="px-4 py-3 text-sm text-gray-600"><%= wc.name %></td>
                <td class="px-4 py-3 text-sm">
                  <span class={"inline-flex rounded-full px-2 py-1 text-xs font-medium #{type_badge(wc.center_type)}"}>
                    <%= WorkCenter.center_type_label(wc.center_type) %>
                  </span>
                </td>
                <td class="px-4 py-3 text-right text-sm text-gray-700"><%= D.to_string(wc.hourly_rate) %> лв.</td>
                <td class="px-4 py-3 text-right text-sm text-gray-700"><%= D.to_string(wc.capacity_per_hour) %></td>
                <td class="px-4 py-3 text-right text-sm text-gray-700"><%= D.to_string(wc.efficiency_percent) %>%</td>
                <td class="px-4 py-3 text-center">
                  <span class={"inline-flex rounded-full px-2 py-1 text-xs font-medium #{status_badge(wc.is_active)}"}>
                    <%= if wc.is_active, do: "Активен", else: "Неактивен" %>
                  </span>
                </td>
                <td class="px-4 py-3 text-right text-sm space-x-2">
                  <.link patch={~p"/work-centers/#{wc.id}/edit"} class="text-indigo-600 hover:text-indigo-700">Редакция</.link>
                  <button type="button" phx-click="delete" phx-value-id={wc.id} data-confirm="Сигурни ли сте?" class="text-red-600 hover:text-red-700">Изтрий</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @work_centers == [] do %>
          <div class="py-12 text-center text-sm text-gray-500">
            Няма намерени работни центрове
          </div>
        <% end %>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="rounded-lg border border-indigo-100 bg-white p-6 shadow-lg">
          <h2 class="text-lg font-semibold text-gray-900">
            <%= if @live_action == :new, do: "Нов работен център", else: "Редакция на работен център" %>
          </h2>

          <.simple_form
            for={@form}
            id="work-center-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:code]} label="Код" />
              <.input field={@form[:name]} label="Име" />
              <.input field={@form[:center_type]} type="select" label="Тип" options={center_type_options()} />
              <.input field={@form[:is_active]} type="select" label="Статус" options={[{"Активен", "true"}, {"Неактивен", "false"}]} />
            </div>

            <div class="grid gap-4 sm:grid-cols-3">
              <.input field={@form[:hourly_rate]} label="Часова ставка (лв.)" type="number" step="0.01" />
              <.input field={@form[:capacity_per_hour]} label="Капацитет на час" type="number" step="0.01" />
              <.input field={@form[:efficiency_percent]} label="Ефективност (%)" type="number" step="0.1" />
            </div>

            <.input field={@form[:description]} type="textarea" label="Описание" rows={3} />
            <.input field={@form[:notes]} type="textarea" label="Бележки" rows={2} />

            <:actions>
              <.button type="submit">Запази</.button>
              <.link patch={~p"/work-centers"} class="text-sm text-gray-500 hover:text-gray-700">Отказ</.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>
    """
  end
end
