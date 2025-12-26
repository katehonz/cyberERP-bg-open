defmodule CyberCore.Accounting.FixedAssets do
  @moduledoc """
  Контекст за управление на дълготрайни активи (ДМА).

  Поддържа:
  - Създаване и управление на активи
  - Изчисляване на амортизация (счетоводна и данъчна)
  - Генериране на графици за амортизация
  - Автоматично създаване на счетоводни записи
  - Извеждане от употреба
  """

  import Ecto.Query, warn: false
  alias CyberCore.Repo
  alias CyberCore.Accounting
  alias CyberCore.Accounting.{Asset, AssetDepreciationSchedule, AssetTransaction}
  alias Decimal, as: D

  # ========== Asset CRUD ==========

  @doc """
  Връща списък с всички активи за даден tenant
  """
  def list_assets(tenant_id, opts \\ []) do
    base_query =
      from a in Asset,
        where: a.tenant_id == ^tenant_id,
        order_by: [asc: a.code]

    base_query
    |> apply_filters(opts)
    |> maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Връща актив по ID
  """
  def get_asset!(tenant_id, id, preloads \\ []) do
    Asset
    |> where([a], a.tenant_id == ^tenant_id and a.id == ^id)
    |> Repo.one!()
    |> Repo.preload(preloads)
  end

  @doc """
  Създава нов актив
  """
  def create_asset(attrs) do
    %Asset{}
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking asset changes
  """
  def change_asset(%Asset{} = asset, attrs \\ %{}) do
    Asset.changeset(asset, attrs)
  end

  @doc """
  Създава нов актив заедно с график за амортизация
  """
  def create_asset_with_schedule(attrs, opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, asset} <- create_asset(attrs),
           {:ok, _schedules} <- generate_depreciation_schedule(asset, opts) do
        Repo.preload(asset, :depreciation_schedule)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Актуализира актив
  """
  def update_asset(%Asset{} = asset, attrs) do
    asset
    |> Asset.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Изтрива актив
  """
  def delete_asset(%Asset{} = asset) do
    Repo.delete(asset)
  end

  @doc """
  Изтрива запис от график за амортизация
  """
  def delete_depreciation_entry(%AssetDepreciationSchedule{} = schedule) do
    Repo.delete(schedule)
  end

  # ========== Depreciation Schedule ==========

  @doc """
  Генерира график за амортизация за даден актив

  Options:
    - start_date: Начална дата (по подразбиране първия ден на следващия месец след придобиването)
    - end_date: Крайна дата (по подразбиране изчислява се от useful_life_months)
    - type: :accounting или :tax (по подразбиране :accounting)
  """
  def generate_depreciation_schedule(%Asset{} = asset, opts \\ []) do
    start_date = opts[:start_date] || calculate_start_date(asset.acquisition_date)
    type = opts[:type] || :accounting

    # Calculate monthly depreciation
    monthly_depreciation = Asset.calculate_monthly_depreciation(asset, type)

    # Generate schedule entries
    schedules =
      0..(asset.useful_life_months - 1)
      |> Enum.map(fn month_offset ->
        # Approximate month
        period_date = Date.add(start_date, month_offset * 30)
        period_date = Date.beginning_of_month(period_date)

        accumulated = D.mult(monthly_depreciation, D.new(month_offset + 1))
        book_value = D.sub(asset.acquisition_cost, accumulated)

        attrs = %{
          tenant_id: asset.tenant_id,
          asset_id: asset.id,
          period_date: period_date,
          amount: monthly_depreciation,
          depreciation_type: Atom.to_string(type),
          accounting_amount: if(type == :accounting, do: monthly_depreciation, else: nil),
          tax_amount: if(type == :tax, do: monthly_depreciation, else: nil),
          accumulated_depreciation: accumulated,
          book_value: book_value,
          status: "planned"
        }

        create_depreciation_entry(attrs)
      end)

    # Check if all succeeded
    errors =
      Enum.filter(schedules, fn
        {:error, _} -> true
        _ -> false
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.map(schedules, fn {:ok, schedule} -> schedule end)}
    else
      {:error, List.first(errors)}
    end
  end

  @doc """
  Създава запис в графика за амортизация
  """
  def create_depreciation_entry(attrs) do
    %AssetDepreciationSchedule{}
    |> AssetDepreciationSchedule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Обновява запис в графика за амортизация
  """
  def update_depreciation_entry(%AssetDepreciationSchedule{} = schedule, attrs) do
    schedule
    |> AssetDepreciationSchedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Връща графика за амортизация на даден актив
  """
  def list_depreciation_schedule(asset_id) do
    Repo.all(
      from s in AssetDepreciationSchedule,
        where: s.asset_id == ^asset_id,
        order_by: [asc: s.period_date]
    )
  end

  @doc """
  Връща планираните записи за амортизация за даден период
  """
  def list_pending_depreciation(tenant_id, period_date) do
    Repo.all(
      from s in AssetDepreciationSchedule,
        join: a in Asset,
        on: s.asset_id == a.id,
        where: s.tenant_id == ^tenant_id,
        where: s.status == "planned",
        where: s.period_date == ^period_date,
        where: a.status == "active",
        preload: [:asset]
    )
  end

  # ========== Posting Depreciation ==========

  @doc """
  Постване на амортизация за даден период

  Създава счетоводен запис:
  Дт 603 Разходи за амортизация
  Кт 2413 Амортизация на ДМА
  """
  def post_depreciation(%AssetDepreciationSchedule{} = schedule) do
    Repo.transaction(fn ->
      asset = Repo.preload(schedule, :asset).asset

      # Validate accounts are set
      with :ok <- validate_asset_accounts(asset),
           {:ok, journal_entry} <- create_depreciation_journal_entry(asset, schedule),
           {:ok, updated_schedule} <-
             update_depreciation_entry(schedule, %{
               status: "posted",
               journal_entry_id: journal_entry.id
             }) do
        updated_schedule
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Постване на всички планирани амортизации за даден период
  """
  def post_period_depreciation(tenant_id, period_date) do
    schedules = list_pending_depreciation(tenant_id, period_date)

    results =
      Enum.map(schedules, fn schedule ->
        case post_depreciation(schedule) do
          {:ok, posted_schedule} -> {:ok, posted_schedule}
          {:error, reason} -> {:error, {schedule, reason}}
        end
      end)

    # Separate successes and failures
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    if Enum.empty?(failures) do
      {:ok, length(successes)}
    else
      {:error, failures}
    end
  end

  # ========== Asset Value Increase with Accounting ==========

  @doc """
  Увеличава стойността на актив със създаване на счетоводен запис

  Създава:
  - Дт 203 ДМА (увеличена стойност)
  - Кт 488 Други пасиви / 301 Материали (според източника)
  """
  def increase_asset_value_with_accounting(%Asset{} = asset, attrs, source_account_id) do
    # Валидираме преди да започнем транзакцията
    with :ok <- can_increase_value?(asset),
         {:ok, transaction_date} <- parse_transaction_date(attrs),
         :ok <- validate_transaction_date(asset, transaction_date) do
      Repo.transaction(fn ->
        # Увеличаваме стойността
        case increase_asset_value(asset, attrs) do
          {:ok, {updated_asset, transaction}} ->
            # Създаваме счетоводен запис
            amount = attrs[:amount] || attrs["amount"]

            transaction_date =
              attrs[:transaction_date] || attrs["transaction_date"] || Date.utc_today()

            entry_attrs = %{
              tenant_id: asset.tenant_id,
              document_date: transaction_date,
              vat_date: transaction_date,
              accounting_date: transaction_date,
              description: attrs[:description] || "Увеличаване на стойността на #{asset.name}",
              source_document_id: transaction.id,
              source_document_type: "AssetTransaction"
            }

            lines_attrs = [
              # Дт 203/206/... ДМА
              %{
                account_id: asset.accounting_account_id,
                debit_amount: amount,
                credit_amount: D.new(0),
                description: "Увеличаване на ДМА - #{asset.name}",
                currency_code: "BGN",
                line_order: 1
              },
              # Кт източник
              %{
                account_id: source_account_id,
                debit_amount: D.new(0),
                credit_amount: amount,
                description: "Източник на увеличението",
                currency_code: "BGN",
                line_order: 2
              }
            ]

            case Accounting.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
              {:ok, journal_entry} ->
                # Обновяваме транзакцията с journal_entry_id
                Repo.update_all(
                  from(t in AssetTransaction, where: t.id == ^transaction.id),
                  set: [journal_entry_id: journal_entry.id]
                )

                {updated_asset, transaction, journal_entry}

              {:error, reason} ->
                Repo.rollback(reason)
            end

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_transaction_date(attrs) do
    date = attrs[:transaction_date] || attrs["transaction_date"] || Date.utc_today()

    case date do
      %Date{} = d ->
        {:ok, d}

      binary when is_binary(binary) ->
        case Date.from_iso8601(binary) do
          {:ok, d} -> {:ok, d}
          _ -> {:error, "Невалидна дата"}
        end

      _ ->
        {:error, "Невалидна дата"}
    end
  end

  # ========== Asset Disposal ==========

  @doc """
  Извеждане на актив от употреба

  Създава счетоводен запис за извеждането
  """
  def dispose_asset(%Asset{} = asset, disposal_attrs) do
    Repo.transaction(fn ->
      # Calculate book value at disposal
      accumulated = calculate_accumulated_depreciation(asset)
      book_value = D.sub(asset.acquisition_cost, accumulated)

      # Create disposal journal entry
      disposal_value = disposal_attrs[:disposal_value] || D.new(0)
      {:ok, journal_entry} = create_disposal_journal_entry(asset, book_value, disposal_value)

      # Update asset
      update_attrs =
        disposal_attrs
        |> Map.put(:status, "disposed")
        |> Map.put(:disposal_journal_entry_id, journal_entry.id)

      case update_asset(asset, update_attrs) do
        {:ok, updated_asset} -> updated_asset
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # ========== Calculations ==========

  @doc """
  Изчислява натрупаната амортизация за даден актив
  """
  def calculate_accumulated_depreciation(%Asset{} = asset) do
    posted_depreciation =
      Repo.aggregate(
        from(s in AssetDepreciationSchedule,
          where: s.asset_id == ^asset.id,
          where: s.status == "posted"
        ),
        :sum,
        :amount
      )

    posted_depreciation || D.new(0)
  end

  @doc """
  Изчислява текущата балансова стойност на актив
  """
  def calculate_book_value(%Asset{} = asset) do
    accumulated = calculate_accumulated_depreciation(asset)
    D.sub(asset.acquisition_cost, accumulated)
  end

  @doc """
  Връща статистика за активи
  """
  def get_assets_statistics(tenant_id) do
    assets = list_assets(tenant_id, preload: [:depreciation_schedule])

    total_count = length(assets)
    active_count = Enum.count(assets, &(&1.status == "active"))
    disposed_count = Enum.count(assets, &(&1.status == "disposed"))

    total_acquisition_cost =
      assets
      |> Enum.map(& &1.acquisition_cost)
      |> Enum.reduce(D.new(0), &D.add/2)

    total_accumulated_depreciation =
      assets
      |> Enum.map(&calculate_accumulated_depreciation/1)
      |> Enum.reduce(D.new(0), &D.add/2)

    total_book_value = D.sub(total_acquisition_cost, total_accumulated_depreciation)

    %{
      total_count: total_count,
      active_count: active_count,
      disposed_count: disposed_count,
      total_acquisition_cost: total_acquisition_cost,
      total_accumulated_depreciation: total_accumulated_depreciation,
      total_book_value: total_book_value
    }
  end

  # ========== Business Validation ==========

  @doc """
  Проверява дали актив може да бъде редактиран
  """
  def can_edit_asset?(%Asset{} = asset) do
    cond do
      asset.status == "disposed" ->
        {:error, "Изведен актив не може да бъде редактиран"}

      has_posted_depreciation?(asset) ->
        {:error, "Актив с постнати амортизации може да бъде редактиран само частично"}

      true ->
        :ok
    end
  end

  @doc """
  Проверява дали актив може да бъде изтрит
  """
  def can_delete_asset?(%Asset{} = asset) do
    cond do
      has_posted_depreciation?(asset) ->
        {:error, "Актив с постнати амортизации не може да бъде изтрит"}

      has_transactions?(asset) ->
        {:error, "Актив с транзакции не може да бъде изтрит"}

      true ->
        :ok
    end
  end

  @doc """
  Проверява дали стойността на актив може да бъде увеличена
  """
  def can_increase_value?(%Asset{} = asset) do
    cond do
      asset.status == "disposed" ->
        {:error, "Не може да увеличите стойността на изведен актив"}

      asset.status == "fully_depreciated" ->
        {:error, "Не може да увеличите стойността на напълно амортизиран актив"}

      true ->
        :ok
    end
  end

  @doc """
  Проверява дали актив може да бъде изведен от употреба
  """
  def can_dispose_asset?(%Asset{} = asset) do
    cond do
      asset.status == "disposed" ->
        {:error, "Активът вече е изведен от употреба"}

      true ->
        :ok
    end
  end

  @doc """
  Проверява дали амортизация може да бъде постната за даден период
  """
  def can_post_depreciation?(asset, period_date) do
    cond do
      asset.status == "disposed" ->
        {:error, "Не може да постнете амортизация за изведен актив"}

      Date.compare(period_date, asset.acquisition_date) == :lt ->
        {:error, "Периодът е преди датата на придобиване"}

      Date.compare(period_date, Date.utc_today()) == :gt ->
        {:error, "Не може да постнете амортизация за бъдещ период"}

      has_posted_depreciation_for_period?(asset, period_date) ->
        {:error, "Амортизация за този период вече е постната"}

      true ->
        :ok
    end
  end

  @doc """
  Валидира дата на транзакция спрямо актив
  """
  def validate_transaction_date(%Asset{} = asset, transaction_date) do
    cond do
      Date.compare(transaction_date, asset.acquisition_date) == :lt ->
        {:error, "Датата на транзакцията не може да бъде преди датата на придобиване"}

      Date.compare(transaction_date, Date.utc_today()) == :gt ->
        {:error, "Датата на транзакцията не може да бъде в бъдещето"}

      asset.disposal_date && Date.compare(transaction_date, asset.disposal_date) == :gt ->
        {:error, "Датата на транзакцията не може да бъде след датата на извеждане"}

      true ->
        :ok
    end
  end

  # Помощни функции за проверки

  defp has_posted_depreciation?(%Asset{id: id}) do
    from(s in AssetDepreciationSchedule,
      where: s.asset_id == ^id and s.posted == true,
      select: count(s.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  defp has_transactions?(%Asset{id: id}) do
    from(t in AssetTransaction,
      where: t.asset_id == ^id,
      select: count(t.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  defp has_posted_depreciation_for_period?(%Asset{id: id}, period_date) do
    from(s in AssetDepreciationSchedule,
      where:
        s.asset_id == ^id and
          s.period_date == ^period_date and
          s.posted == true,
      select: count(s.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  # ========== Private Helpers ==========

  defp calculate_start_date(acquisition_date) do
    # Start depreciation from the first day of the next month
    acquisition_date
    # Move to next month
    |> Date.add(32)
    |> Date.beginning_of_month()
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, acc when status not in [nil, ""] ->
        from a in acc, where: a.status == ^status

      {:tax_category, category}, acc when category not in [nil, ""] ->
        from a in acc, where: a.tax_category == ^category

      {:category, category}, acc when category not in [nil, ""] ->
        from a in acc, where: a.category == ^category

      {:search, term}, acc when is_binary(term) and term != "" ->
        pattern = "%#{term}%"
        from a in acc, where: ilike(a.name, ^pattern) or ilike(a.code, ^pattern)

      _, acc ->
        acc
    end)
  end

  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, preload), do: from(q in query, preload: ^preload)

  defp validate_asset_accounts(%Asset{
         expense_account_id: expense_id,
         accumulated_depreciation_account_id: accum_id
       })
       when not is_nil(expense_id) and not is_nil(accum_id) do
    :ok
  end

  defp validate_asset_accounts(_asset) do
    {:error, "Активът трябва да има зададени сметки за разходи и амортизация"}
  end

  defp create_depreciation_journal_entry(
         %Asset{} = asset,
         %AssetDepreciationSchedule{} = schedule
       ) do
    entry_attrs = %{
      tenant_id: asset.tenant_id,
      document_date: schedule.period_date,
      vat_date: schedule.period_date,
      accounting_date: schedule.period_date,
      description: "Амортизация на #{asset.name} за #{Date.to_iso8601(schedule.period_date)}",
      source_document_id: schedule.id,
      source_document_type: "AssetDepreciationSchedule"
    }

    lines_attrs = [
      # Дт 603 Разходи за амортизация
      %{
        account_id: asset.expense_account_id,
        debit_amount: schedule.amount,
        credit_amount: D.new(0),
        description: "Разходи за амортизация - #{asset.name}",
        currency_code: "BGN",
        line_order: 1
      },
      # Кт 2413 Амортизация на ДМА
      %{
        account_id: asset.accumulated_depreciation_account_id,
        debit_amount: D.new(0),
        credit_amount: schedule.amount,
        description: "Амортизация - #{asset.name}",
        currency_code: "BGN",
        line_order: 2
      }
    ]

    Accounting.create_journal_entry_with_lines(entry_attrs, lines_attrs)
  end

  defp create_disposal_journal_entry(%Asset{} = asset, book_value, disposal_value) do
    accumulated = calculate_accumulated_depreciation(asset)

    # Simplified disposal entry - in reality this would be more complex
    entry_attrs = %{
      tenant_id: asset.tenant_id,
      document_date: asset.disposal_date,
      vat_date: asset.disposal_date,
      accounting_date: asset.disposal_date,
      description: "Извеждане от употреба на #{asset.name}",
      source_document_id: asset.id,
      source_document_type: "Asset"
    }

    # Build lines for disposal
    lines_attrs = [
      # Reverse accumulated depreciation
      %{
        account_id: asset.accumulated_depreciation_account_id,
        debit_amount: accumulated,
        credit_amount: D.new(0),
        description: "Приключване на амортизация",
        currency_code: "BGN",
        line_order: 1
      },
      # Remove asset from books
      %{
        account_id: asset.accounting_account_id,
        debit_amount: D.new(0),
        credit_amount: asset.acquisition_cost,
        description: "Извеждане на актив",
        currency_code: "BGN",
        line_order: 2
      }
    ]

    # Add gain/loss if there's a disposal value different from book value
    lines_attrs =
      if D.compare(disposal_value, book_value) != :eq do
        difference = D.sub(disposal_value, book_value)

        gain_loss_line =
          if D.compare(difference, D.new(0)) == :gt do
            # Gain
            %{
              account_id: asset.accounting_account_id,
              debit_amount: difference,
              credit_amount: D.new(0),
              description: "Печалба от извеждане",
              currency_code: "BGN",
              line_order: 3
            }
          else
            # Loss
            %{
              account_id: asset.accounting_account_id,
              debit_amount: D.new(0),
              credit_amount: D.abs(difference),
              description: "Загуба от извеждане",
              currency_code: "BGN",
              line_order: 3
            }
          end

        lines_attrs ++ [gain_loss_line]
      else
        lines_attrs
      end

    Accounting.create_journal_entry_with_lines(entry_attrs, lines_attrs)
  end

  # ========== Asset Transactions ==========

  @doc """
  Създава транзакция за актив (за SAF-T отчитане)
  """
  def create_asset_transaction(attrs) do
    %AssetTransaction{}
    |> AssetTransaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Връща списък с транзакции за даден актив
  """
  def list_asset_transactions(asset_id) do
    Repo.all(
      from t in AssetTransaction,
        where: t.asset_id == ^asset_id,
        order_by: [desc: t.transaction_date]
    )
  end

  @doc """
  Връща всички транзакции за период (за SAF-T годишен файл)
  """
  def list_asset_transactions_for_period(tenant_id, year) do
    Repo.all(
      from t in AssetTransaction,
        join: a in Asset,
        on: t.asset_id == a.id,
        where: t.tenant_id == ^tenant_id,
        where: t.year == ^year,
        order_by: [asc: t.transaction_date, asc: a.code],
        preload: [:asset, :supplier_customer, :journal_entry]
    )
  end

  @doc """
  Увеличава стойността на актив (подобрение)

  Този метод:
  1. Актуализира acquisition_cost на актива
  2. Създава транзакция тип "20" (IMP - Подобрение)
  3. Преизчислява амортизационния график
  4. Създава счетоводен запис (ако е зададен)

  ## Parameters
  - `asset` - Актива, чиято стойност се увеличава
  - `attrs` - Атрибути:
    - `amount` - Сума на увеличението (задължително)
    - `transaction_date` - Дата на транзакцията (по подразбиране днес)
    - `description` - Описание на подобрението
    - `month_value_change` - Месец на промяна (автоматично от датата)
    - `create_journal_entry` - Дали да създаде счетоводен запис (по подразбиране false)

  ## Returns
  {:ok, {updated_asset, transaction}} | {:error, reason}
  """
  def increase_asset_value(%Asset{} = asset, attrs) do
    amount = attrs[:amount] || attrs["amount"]

    unless amount && D.compare(amount, D.new(0)) == :gt do
      {:error, "Сумата трябва да е положително число"}
    else
      Repo.transaction(fn ->
        transaction_date =
          attrs[:transaction_date] || attrs["transaction_date"] || Date.utc_today()

        month_change = transaction_date.month

        # Calculate new acquisition cost
        new_acquisition_cost = D.add(asset.acquisition_cost, amount)

        # Update asset
        asset_attrs = %{
          acquisition_cost: new_acquisition_cost,
          month_value_change: month_change
        }

        {:ok, updated_asset} =
          case update_asset(asset, asset_attrs) do
            {:ok, a} -> {:ok, a}
            {:error, changeset} -> Repo.rollback(changeset)
          end

        # Create transaction record
        transaction_attrs = %{
          tenant_id: asset.tenant_id,
          asset_id: asset.id,
          # IMP - Improvement
          transaction_type: "20",
          transaction_date: transaction_date,
          description: attrs[:description] || attrs["description"] || "Увеличаване на стойността",
          transaction_amount: amount,
          acquisition_cost_change: amount,
          book_value_after: calculate_book_value(updated_asset)
        }

        {:ok, transaction} =
          case create_asset_transaction(transaction_attrs) do
            {:ok, t} -> {:ok, t}
            {:error, changeset} -> Repo.rollback(changeset)
          end

        # Optionally regenerate depreciation schedule
        # This would cancel existing schedules and create new ones
        if attrs[:regenerate_schedule] do
          # Delete future schedules
          Repo.delete_all(
            from s in AssetDepreciationSchedule,
              where: s.asset_id == ^asset.id,
              where: s.status == "planned"
          )

          # Generate new schedule
          case generate_depreciation_schedule(updated_asset) do
            {:ok, _} -> :ok
            {:error, reason} -> Repo.rollback(reason)
          end
        end

        {updated_asset, transaction}
      end)
    end
  end

  @doc """
  Записва транзакция за придобиване на актив
  """
  def record_acquisition_transaction(%Asset{} = asset) do
    transaction_attrs = %{
      tenant_id: asset.tenant_id,
      asset_id: asset.id,
      # ACQ - Acquisition
      transaction_type: "10",
      transaction_date: asset.acquisition_date,
      description: "Придобиване на актив",
      transaction_amount: asset.acquisition_cost,
      acquisition_cost_change: asset.acquisition_cost,
      book_value_after: asset.acquisition_cost,
      supplier_customer_id: asset.supplier_id
    }

    create_asset_transaction(transaction_attrs)
  end

  @doc """
  Записва транзакция за амортизация
  """
  def record_depreciation_transaction(%AssetDepreciationSchedule{} = schedule) do
    asset = Repo.preload(schedule, :asset).asset

    transaction_attrs = %{
      tenant_id: asset.tenant_id,
      asset_id: asset.id,
      # DEP - Depreciation
      transaction_type: "30",
      transaction_date: schedule.period_date,
      description: "Амортизация за #{Date.to_iso8601(schedule.period_date)}",
      transaction_amount: schedule.amount,
      acquisition_cost_change: D.new(0),
      book_value_after: schedule.book_value,
      journal_entry_id: schedule.journal_entry_id
    }

    create_asset_transaction(transaction_attrs)
  end

  @doc """
  Записва транзакция за извеждане от употреба
  """
  def record_disposal_transaction(%Asset{} = asset, disposal_type \\ "50") do
    _book_value = calculate_book_value(asset)

    transaction_attrs = %{
      tenant_id: asset.tenant_id,
      asset_id: asset.id,
      # 50=DSP (Sale), 60=SCR (Scrap)
      transaction_type: disposal_type,
      transaction_date: asset.disposal_date,
      description: asset.disposal_reason || "Извеждане от употреба",
      transaction_amount: asset.disposal_value || D.new(0),
      acquisition_cost_change: D.mult(asset.acquisition_cost, D.new(-1)),
      book_value_after: D.new(0),
      journal_entry_id: asset.disposal_journal_entry_id
    }

    create_asset_transaction(transaction_attrs)
  end

  @doc """
  Подготвя данни за начало на годината (за SAF-T отчитане)

  Тази функция трябва да се изпълнява в началото на всяка година
  за да запази началните стойности необходими за годишния SAF-T файл
  """
  def prepare_year_beginning_values(tenant_id, _year) do
    assets = list_assets(tenant_id, status: "active")

    Enum.each(assets, fn asset ->
      accumulated = calculate_accumulated_depreciation(asset)
      book_value = calculate_book_value(asset)

      update_asset(asset, %{
        acquisition_cost_begin_year: asset.acquisition_cost,
        book_value_begin_year: book_value,
        accumulated_depreciation_begin_year: accumulated,
        depreciation_months_current_year: 0
      })
    end)

    {:ok, length(assets)}
  end
end
