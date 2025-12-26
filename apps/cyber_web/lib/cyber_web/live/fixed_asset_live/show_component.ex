defmodule CyberWeb.FixedAssetLive.ShowComponent do
  use CyberWeb, :live_component

  alias CyberCore.Accounting.FixedAssets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="d-flex justify-content-between align-items-center mb-4">
        <h3><%= @asset.name %></h3>
        <span class={"badge bg-gradient-#{status_badge(@asset.status)} font-size-sm"}>
          <%= status_label(@asset.status) %>
        </span>
      </div>

      <!-- Main Info Cards -->
      <div class="row mb-4">
        <div class="col-md-3">
          <div class="card">
            <div class="card-body p-3">
              <p class="text-sm mb-1 text-capitalize font-weight-bold">Стойност придобиване</p>
              <h5 class="font-weight-bolder mb-0"><%= format_currency(@asset.acquisition_cost) %></h5>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card">
            <div class="card-body p-3">
              <p class="text-sm mb-1 text-capitalize font-weight-bold">Начислена амортизация</p>
              <h5 class="font-weight-bolder mb-0 text-warning">
                <%= format_currency(@accumulated_depreciation) %>
              </h5>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card">
            <div class="card-body p-3">
              <p class="text-sm mb-1 text-capitalize font-weight-bold">Балансова стойност</p>
              <h5 class="font-weight-bolder mb-0 text-success">
                <%= format_currency(@book_value) %>
              </h5>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card">
            <div class="card-body p-3">
              <p class="text-sm mb-1 text-capitalize font-weight-bold">Процент амортизация</p>
              <h5 class="font-weight-bolder mb-0">
                <%= calculate_depreciation_percent(@asset, @accumulated_depreciation) %>%
              </h5>
            </div>
          </div>
        </div>
      </div>

      <!-- Detailed Information Tabs -->
      <div class="card">
        <div class="card-header p-3">
          <ul class="nav nav-tabs" role="tablist">
            <li class="nav-item">
              <a
                class="nav-link active"
                data-bs-toggle="tab"
                href="#general"
                role="tab"
              >
                <i class="fas fa-info-circle me-2"></i>Обща информация
              </a>
            </li>
            <li class="nav-item">
              <a
                class="nav-link"
                data-bs-toggle="tab"
                href="#depreciation"
                role="tab"
              >
                <i class="fas fa-chart-line me-2"></i>Амортизация
              </a>
            </li>
            <li class="nav-item">
              <a
                class="nav-link"
                data-bs-toggle="tab"
                href="#accounts"
                role="tab"
              >
                <i class="fas fa-book me-2"></i>Счетоводство
              </a>
            </li>
            <li class="nav-item">
              <a
                class="nav-link"
                data-bs-toggle="tab"
                href="#transactions"
                role="tab"
              >
                <i class="fas fa-exchange-alt me-2"></i>Транзакции
              </a>
            </li>
          </ul>
        </div>

        <div class="card-body">
          <div class="tab-content">
            <!-- General Tab -->
            <div class="tab-pane fade show active" id="general" role="tabpanel">
              <div class="row">
                <div class="col-md-6">
                  <h6 class="text-sm font-weight-bold mb-3">Основни данни</h6>
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <td class="text-sm font-weight-bold">Код:</td>
                        <td class="text-sm"><%= @asset.code %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Инвентарен №:</td>
                        <td class="text-sm"><%= @asset.inventory_number || "-" %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Сериен №:</td>
                        <td class="text-sm"><%= @asset.serial_number || "-" %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Категория:</td>
                        <td class="text-sm"><%= @asset.category %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Местонахождение:</td>
                        <td class="text-sm"><%= @asset.location || "-" %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">МОЛ:</td>
                        <td class="text-sm"><%= @asset.responsible_person || "-" %></td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div class="col-md-6">
                  <h6 class="text-sm font-weight-bold mb-3">Придобиване</h6>
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <td class="text-sm font-weight-bold">Дата придобиване:</td>
                        <td class="text-sm">
                          <%= Calendar.strftime(@asset.acquisition_date, "%d.%m.%Y") %>
                        </td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Стойност:</td>
                        <td class="text-sm"><%= format_currency(@asset.acquisition_cost) %></td>
                      </tr>
                      <%= if @asset.supplier do %>
                        <tr>
                          <td class="text-sm font-weight-bold">Доставчик:</td>
                          <td class="text-sm"><%= @asset.supplier.name %></td>
                        </tr>
                      <% end %>
                      <%= if @asset.invoice_number do %>
                        <tr>
                          <td class="text-sm font-weight-bold">Фактура №:</td>
                          <td class="text-sm"><%= @asset.invoice_number %></td>
                        </tr>
                      <% end %>
                      <%= if @asset.invoice_date do %>
                        <tr>
                          <td class="text-sm font-weight-bold">Дата фактура:</td>
                          <td class="text-sm">
                            <%= Calendar.strftime(@asset.invoice_date, "%d.%m.%Y") %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>

              <%= if @asset.notes do %>
                <div class="row mt-3">
                  <div class="col-12">
                    <h6 class="text-sm font-weight-bold mb-2">Забележки</h6>
                    <p class="text-sm"><%= @asset.notes %></p>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Depreciation Tab -->
            <div class="tab-pane fade" id="depreciation" role="tabpanel">
              <div class="row mb-3">
                <div class="col-md-6">
                  <h6 class="text-sm font-weight-bold mb-3">Данъчна амортизация (ЗКПО)</h6>
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <td class="text-sm font-weight-bold">Категория:</td>
                        <td class="text-sm"><%= tax_category_label(@asset.tax_category) %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Данъчна норма:</td>
                        <td class="text-sm">
                          <%= if @asset.tax_depreciation_rate do %>
                            <%= Decimal.mult(@asset.tax_depreciation_rate, Decimal.new(100)) |> Decimal.to_string() %>%
                          <% else %>
                            -
                          <% end %>
                        </td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Годишна данъчна амортизация:</td>
                        <td class="text-sm font-weight-bold text-primary">
                          <%= format_currency(calculate_annual_depreciation(@asset, :tax)) %>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div class="col-md-6">
                  <h6 class="text-sm font-weight-bold mb-3">Счетоводна амортизация</h6>
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <td class="text-sm font-weight-bold">Метод:</td>
                        <td class="text-sm"><%= depreciation_method_label(@asset.depreciation_method) %></td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Счетоводна норма:</td>
                        <td class="text-sm">
                          <%= if @asset.accounting_depreciation_rate do %>
                            <%= Decimal.mult(@asset.accounting_depreciation_rate, Decimal.new(100)) |> Decimal.to_string() %>%
                          <% else %>
                            -
                          <% end %>
                        </td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Годишна счетоводна амортизация:</td>
                        <td class="text-sm font-weight-bold text-success">
                          <%= format_currency(calculate_annual_depreciation(@asset, :accounting)) %>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              <div class="row">
                <div class="col-md-12">
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <td class="text-sm font-weight-bold">Полезен живот:</td>
                        <td class="text-sm"><%= @asset.useful_life_months %> месеца</td>
                      </tr>
                      <tr>
                        <td class="text-sm font-weight-bold">Ликвидационна стойност:</td>
                        <td class="text-sm"><%= format_currency(@asset.salvage_value) %></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <!-- Accounts Tab -->
            <div class="tab-pane fade" id="accounts" role="tabpanel">
              <table class="table table-sm">
                <tbody>
                  <%= if @asset.accounting_account do %>
                    <tr>
                      <td class="text-sm font-weight-bold">Сметка ДМА:</td>
                      <td class="text-sm">
                        <%= @asset.accounting_account.code %> - <%= @asset.accounting_account.name %>
                      </td>
                    </tr>
                  <% end %>
                  <%= if @asset.expense_account do %>
                    <tr>
                      <td class="text-sm font-weight-bold">Сметка разходи:</td>
                      <td class="text-sm">
                        <%= @asset.expense_account.code %> - <%= @asset.expense_account.name %>
                      </td>
                    </tr>
                  <% end %>
                  <%= if @asset.accumulated_depreciation_account do %>
                    <tr>
                      <td class="text-sm font-weight-bold">Сметка амортизация:</td>
                      <td class="text-sm">
                        <%= @asset.accumulated_depreciation_account.code %> - <%= @asset.accumulated_depreciation_account.name %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <!-- Transactions Tab -->
            <div class="tab-pane fade" id="transactions" role="tabpanel">
              <%= if @asset.transactions && Enum.any?(@asset.transactions) do %>
                <table class="table table-sm table-hover">
                  <thead>
                    <tr>
                      <th class="text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">Дата</th>
                      <th class="text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">Тип</th>
                      <th class="text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">Описание</th>
                      <th class="text-uppercase text-secondary text-xxs font-weight-bolder opacity-7 text-end">Сума</th>
                      <th class="text-uppercase text-secondary text-xxs font-weight-bolder opacity-7 text-end">Балансова стойност</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for tx <- @asset.transactions do %>
                      <tr>
                        <td class="text-sm"><%= Calendar.strftime(tx.transaction_date, "%d.%m.%Y") %></td>
                        <td class="text-sm">
                          <span class={"badge bg-gradient-#{get_transaction_color(tx.transaction_type)} font-size-sm"}>
                            <%= tx.transaction_type_name %>
                          </span>
                        </td>
                        <td class="text-sm"><%= tx.description %></td>
                        <td class="text-sm text-end"><%= format_currency(tx.transaction_amount) %></td>
                        <td class="text-sm text-end"><%= format_currency(tx.book_value_after) %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              <% else %>
                <div class="text-center p-4">
                  <p>Няма регистрирани транзакции за този актив.</p>
                </div>
              <% end %>
            </div>

          </div>
        </div>
      </div>

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
    asset = assigns.asset |> CyberCore.Repo.preload([:transactions])
    accumulated_depreciation = FixedAssets.calculate_accumulated_depreciation(asset)
    book_value = FixedAssets.calculate_book_value(asset)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:asset, asset)
     |> assign(:accumulated_depreciation, accumulated_depreciation)
     |> assign(:book_value, book_value)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  defp status_badge("active"), do: "success"
  defp status_badge("disposed"), do: "danger"
  defp status_badge("fully_depreciated"), do: "warning"
  defp status_badge(_), do: "secondary"

  defp status_label("active"), do: "Активен"
  defp status_label("inactive"), do: "Неактивен"
  defp status_label("disposed"), do: "Изведен"
  defp status_label("fully_depreciated"), do: "Напълно амортизиран"
  defp status_label(_), do: "Неизвестен"

  defp tax_category_label(nil), do: "-"

  defp tax_category_label(category) do
    case CyberCore.Accounting.Asset.tax_category_info(category) do
      %{name: name} -> "#{category} - #{name}"
      _ -> category
    end
  end

  defp depreciation_method_label("straight_line"), do: "Линеен"
  defp depreciation_method_label("declining_balance"), do: "Намаляващ"
  defp depreciation_method_label("units_of_production"), do: "По единици"
  defp depreciation_method_label(_), do: "-"

  defp get_transaction_color("10"), do: "success" # ACQ
  defp get_transaction_color("20"), do: "info"    # IMP
  defp get_transaction_color("30"), do: "secondary" # DEP
  defp get_transaction_color("40"), do: "warning" # REV
  defp get_transaction_color("50"), do: "primary" # DSP
  defp get_transaction_color("60"), do: "danger"  # SCR
  defp get_transaction_color(_), do: "light"

  defp calculate_annual_depreciation(asset, type) do
    CyberCore.Accounting.Asset.calculate_annual_depreciation(asset, type)
  end

  defp calculate_depreciation_percent(asset, accumulated) do
    if Decimal.compare(asset.acquisition_cost, Decimal.new(0)) == :gt do
      accumulated
      |> Decimal.div(asset.acquisition_cost)
      |> Decimal.mult(Decimal.new(100))
      |> Decimal.round(2)
      |> Decimal.to_string()
    else
      "0"
    end
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
