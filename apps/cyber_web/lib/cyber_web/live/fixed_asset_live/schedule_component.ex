defmodule CyberWeb.FixedAssetLive.ScheduleComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting.FixedAssets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="mb-4">График за амортизация - <%= @asset.name %></h3>

      <!-- Asset Summary Card -->
      <div class="card mb-4">
        <div class="card-header pb-0">
          <h6>Информация за актива</h6>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Код:</strong></p>
              <p class="text-sm"><%= @asset.code %></p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Стойност на придобиване:</strong></p>
              <p class="text-sm font-weight-bold text-primary">
                <%= format_currency(@asset.acquisition_cost) %>
              </p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Начислена амортизация:</strong></p>
              <p class="text-sm font-weight-bold text-warning">
                <%= format_currency(@accumulated_depreciation) %>
              </p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Балансова стойност:</strong></p>
              <p class="text-sm font-weight-bold text-success">
                <%= format_currency(@book_value) %>
              </p>
            </div>
          </div>
          <div class="row mt-3">
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Дата на придобиване:</strong></p>
              <p class="text-sm"><%= Calendar.strftime(@asset.acquisition_date, "%d.%m.%Y") %></p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Полезен живот:</strong></p>
              <p class="text-sm"><%= @asset.useful_life_months %> месеца</p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Данъчна категория:</strong></p>
              <p class="text-sm"><%= @asset.tax_category || "-" %></p>
            </div>
            <div class="col-md-3">
              <p class="text-sm mb-1"><strong>Метод на амортизация:</strong></p>
              <p class="text-sm"><%= depreciation_method_label(@asset.depreciation_method) %></p>
            </div>
          </div>

          <!-- Progress Bar -->
          <div class="row mt-4">
            <div class="col-12">
              <p class="text-sm mb-2"><strong>Прогрес на амортизация:</strong></p>
              <div class="progress">
                <div
                  class="progress-bar bg-gradient-primary"
                  role="progressbar"
                  style={"width: #{@depreciation_percent}%"}
                  aria-valuenow={@depreciation_percent}
                  aria-valuemin="0"
                  aria-valuemax="100"
                >
                  <%= @depreciation_percent %>%
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%= if Enum.empty?(@depreciation_schedule) do %>
        <div class="alert alert-info">
          <div class="d-flex align-items-center">
            <i class="fas fa-info-circle fa-2x me-3"></i>
            <div>
              <h6 class="mb-1">Няма генериран график за амортизация</h6>
              <p class="mb-0 text-sm">
                Натиснете бутона "Генерирай график", за да създадете автоматичен месечен график
                за амортизация според зададените параметри на актива.
              </p>
            </div>
          </div>
          <button
            type="button"
            class="btn btn-sm btn-primary mt-3"
            phx-click="generate_schedule"
            phx-target={@myself}
            phx-disable-with="Генериране..."
          >
            <i class="fas fa-cog me-2"></i>Генерирай график
          </button>
        </div>
      <% else %>
        <!-- Schedule Actions -->
        <div class="card mb-3">
          <div class="card-body p-3">
            <div class="d-flex justify-content-between align-items-center">
              <div>
                <h6 class="mb-0">Действия</h6>
                <p class="text-sm mb-0 text-muted">
                  Общо записи: <%= length(@depreciation_schedule) %> |
                  Постнати: <%= count_posted(@depreciation_schedule) %> |
                  Планирани: <%= count_planned(@depreciation_schedule) %>
                </p>
              </div>
              <div class="btn-group">
                <button
                  type="button"
                  class="btn btn-sm btn-warning"
                  phx-click="regenerate_schedule"
                  phx-target={@myself}
                  data-confirm="Сигурни ли сте? Това ще изтрие съществуващия график."
                >
                  <i class="fas fa-sync me-2"></i>Регенерирай
                </button>
                <button
                  type="button"
                  class="btn btn-sm btn-success"
                  phx-click="post_current_month"
                  phx-target={@myself}
                  phx-disable-with="Постване..."
                >
                  <i class="fas fa-check me-2"></i>Постни текущ месец
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Schedule Table -->
        <div class="card">
          <div class="card-header pb-0">
            <h6>График за амортизация</h6>
          </div>
          <div class="card-body px-0 pt-0 pb-2">
            <div class="table-responsive p-0">
              <table class="table align-items-center mb-0">
                <thead>
                  <tr>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder">Период</th>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder">Тип</th>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder text-end">
                      Месечна амортизация
                    </th>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder text-end">
                      Натрупана амортизация
                    </th>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder text-end">
                      Балансова стойност
                    </th>
                    <th class="text-uppercase text-secondary text-xxs font-weight-bolder text-center">
                      Статус
                    </th>
                    <th class="text-secondary"></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for schedule <- @depreciation_schedule do %>
                    <tr class={row_class(schedule)}>
                      <td>
                        <p class="text-xs font-weight-bold mb-0">
                          <%= Calendar.strftime(schedule.period_date, "%B %Y") %>
                        </p>
                        <p class="text-xs text-secondary mb-0">
                          <%= Calendar.strftime(schedule.period_date, "%d.%m.%Y") %>
                        </p>
                      </td>
                      <td>
                        <span class={"badge badge-sm bg-#{type_badge(schedule.depreciation_type)}"}>
                          <%= type_label(schedule.depreciation_type) %>
                        </span>
                      </td>
                      <td class="text-end">
                        <p class="text-xs font-weight-bold mb-0">
                          <%= format_currency(schedule.amount || Decimal.new(0)) %>
                        </p>
                      </td>
                      <td class="text-end">
                        <p class="text-xs font-weight-bold mb-0 text-warning">
                          <%= format_currency(schedule.accumulated_depreciation || Decimal.new(0)) %>
                        </p>
                      </td>
                      <td class="text-end">
                        <p class="text-xs font-weight-bold mb-0 text-success">
                          <%= format_currency(schedule.book_value || Decimal.new(0)) %>
                        </p>
                      </td>
                      <td class="text-center">
                        <span class={"badge badge-sm bg-gradient-#{status_badge(schedule.status)}"}>
                          <%= status_label(schedule.status) %>
                        </span>
                      </td>
                      <td class="align-middle">
                        <%= if schedule.status == "planned" do %>
                          <button
                            type="button"
                            class="btn btn-link text-success btn-sm mb-0"
                            phx-click="post_single"
                            phx-value-id={schedule.id}
                            phx-target={@myself}
                            title="Постни амортизация"
                          >
                            <i class="fas fa-check"></i>
                          </button>
                        <% end %>
                        <%= if schedule.status == "posted" && schedule.journal_entry_id do %>
                          <a
                            href={"/journal-entries/#{schedule.journal_entry_id}"}
                            class="btn btn-link text-info btn-sm mb-0"
                            title="Виж запис"
                          >
                            <i class="fas fa-eye"></i>
                          </a>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
                <tfoot>
                  <tr class="bg-light">
                    <td colspan="2" class="text-sm font-weight-bold">ОБЩО:</td>
                    <td class="text-end text-sm font-weight-bold">
                      <%= format_currency(calculate_total_amount(@depreciation_schedule)) %>
                    </td>
                    <td class="text-end text-sm font-weight-bold text-warning">
                      <%= format_currency(@accumulated_depreciation) %>
                    </td>
                    <td class="text-end text-sm font-weight-bold text-success">
                      <%= format_currency(@book_value) %>
                    </td>
                    <td colspan="2"></td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>
        </div>
      <% end %>

      <div class="d-flex justify-content-end mt-4">
        <button
          type="button"
          class="btn btn-secondary"
          phx-click="close_modal"
          phx-target={@myself}
        >
          Затвори
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    accumulated_depreciation = FixedAssets.calculate_accumulated_depreciation(assigns.asset)
    book_value = FixedAssets.calculate_book_value(assigns.asset)

    depreciation_percent =
      if Decimal.compare(assigns.asset.acquisition_cost, Decimal.new(0)) == :gt do
        accumulated_depreciation
        |> Decimal.div(assigns.asset.acquisition_cost)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(0)
        |> Decimal.to_integer()
      else
        0
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:accumulated_depreciation, accumulated_depreciation)
     |> assign(:book_value, book_value)
     |> assign(:depreciation_percent, depreciation_percent)}
  end

  @impl true
  def handle_event("generate_schedule", _params, socket) do
    case FixedAssets.generate_depreciation_schedule(socket.assigns.asset) do
      {:ok, _schedules} ->
        {:noreply,
         socket
         |> put_flash(:info, "Графикът за амортизация беше генериран успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при генериране на график")}
    end
  end

  def handle_event("regenerate_schedule", _params, socket) do
    # Delete existing schedule
    socket.assigns.depreciation_schedule
    |> Enum.each(fn schedule ->
      FixedAssets.delete_depreciation_entry(schedule)
    end)

    # Generate new schedule
    case FixedAssets.generate_depreciation_schedule(socket.assigns.asset) do
      {:ok, _schedules} ->
        {:noreply,
         socket
         |> put_flash(:info, "Графикът за амортизация беше регенериран успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при регенериране на график")}
    end
  end

  def handle_event("post_current_month", _params, socket) do
    today = Date.utc_today()
    current_month_start = Date.beginning_of_month(today)

    case FixedAssets.post_period_depreciation(socket.assigns.asset.tenant_id, current_month_start) do
      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(:info, "Постнати #{count} записа за амортизация")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при постване на амортизация")}
    end
  end

  def handle_event("post_single", %{"id" => id}, socket) do
    schedule =
      Enum.find(socket.assigns.depreciation_schedule, fn s ->
        s.id == String.to_integer(id)
      end)

    case FixedAssets.post_depreciation(schedule) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Амортизацията беше постната успешно")
         |> push_patch(to: socket.assigns.patch)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Грешка при постване на амортизация")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  # Helper for deleting depreciation entry
  defp delete_depreciation_entry(schedule) do
    CyberCore.Repo.delete(schedule)
  end

  defp depreciation_method_label("straight_line"), do: "Линеен"
  defp depreciation_method_label("declining_balance"), do: "Намаляващ"
  defp depreciation_method_label("units_of_production"), do: "По единици"
  defp depreciation_method_label(_), do: "-"

  defp status_badge("posted"), do: "success"
  defp status_badge("planned"), do: "info"
  defp status_badge("skipped"), do: "warning"
  defp status_badge(_), do: "secondary"

  defp status_label("posted"), do: "Постнат"
  defp status_label("planned"), do: "Планиран"
  defp status_label("skipped"), do: "Пропуснат"
  defp status_label(_), do: "Неизвестен"

  defp type_badge("accounting"), do: "primary"
  defp type_badge("tax"), do: "warning"
  defp type_badge(_), do: "secondary"

  defp type_label("accounting"), do: "Счетоводна"
  defp type_label("tax"), do: "Данъчна"
  defp type_label(_), do: "-"

  defp row_class(%{status: "posted"}), do: "bg-light-success"
  defp row_class(_), do: ""

  defp count_posted(schedules) do
    Enum.count(schedules, fn s -> s.status == "posted" end)
  end

  defp count_planned(schedules) do
    Enum.count(schedules, fn s -> s.status == "planned" end)
  end

  defp calculate_total_amount(schedules) do
    schedules
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new(0), fn amount, acc ->
      if amount, do: Decimal.add(acc, amount), else: acc
    end)
  end

  defp format_currency(amount) when is_nil(amount), do: "0.00 лв."

  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_currency_string()
  end

  defp format_currency_string(str) do
    [int_part, dec_part] = String.split(str <> ".00", ".") |> Enum.take(2)

    formatted_int =
      int_part
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(" ")
      |> String.reverse()

    "#{formatted_int}.#{String.pad_trailing(dec_part, 2, "0")} лв."
  end
end
