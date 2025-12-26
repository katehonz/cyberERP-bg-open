defmodule Mix.Tasks.ImportChartOfAccounts do
  @moduledoc """
  Импортира сметкоплан от CSV файл.

  Използване:
      mix import_chart_of_accounts [tenant_id]

  Примери:
      mix import_chart_of_accounts
      mix import_chart_of_accounts 1
  """
  use Mix.Task

  @shortdoc "Импортира сметкоплан от FILE/chart-account.csv"

  alias CyberCore.Accounting
  alias CyberCore.Repo

  def run(args) do
    Mix.Task.run("app.start")

    tenant_id =
      case args do
        [id] -> String.to_integer(id)
        _ -> 1
      end

    csv_path = Path.join([File.cwd!(), "FILE", "chart-account.csv"])

    IO.puts("Импортиране на сметкоплан от: #{csv_path}")
    IO.puts("Tenant ID: #{tenant_id}")
    IO.puts("")

    case File.read(csv_path) do
      {:ok, content} ->
        import_accounts(content, tenant_id)

      {:error, reason} ->
        IO.puts("Грешка при четене на файла: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp import_accounts(content, tenant_id) do
    lines = String.split(content, "\n")

    # Пропускаме заглавния ред и празните редове
    accounts_data =
      lines
      # Пропускаме "Код ,Име на сметка"
      |> Enum.drop(1)
      |> Enum.map(&parse_line/1)
      |> Enum.reject(&is_nil/1)

    IO.puts("Намерени #{length(accounts_data)} сметки за импортиране")
    IO.puts("")

    {success, failed} =
      Enum.reduce(accounts_data, {0, 0}, fn account_data, {succ, fail} ->
        case create_account(account_data, tenant_id) do
          {:ok, _account} ->
            IO.write(".")
            {succ + 1, fail}

          {:error, changeset} ->
            IO.puts("\nГрешка при импорт на сметка #{account_data.code}:")
            IO.inspect(changeset.errors)
            {succ, fail + 1}
        end
      end)

    IO.puts("\n")
    IO.puts("Готово!")
    IO.puts("Успешно импортирани: #{success}")
    IO.puts("Грешки: #{failed}")
  end

  defp parse_line(line) do
    line = String.trim(line)

    # Пропускаме празни редове и последния ред "ОБЩА СУМА"
    if line == "" or String.starts_with?(line, "ОБЩА СУМА") do
      nil
    else
      case String.split(line, ",", parts: 2) do
        [code_str, name] ->
          code = String.trim(code_str)
          name = String.trim(name, "\"") |> String.trim()

          # Пропускаме редове без код
          if code == "" do
            nil
          else
            account_class = derive_class(code)
            account_type = derive_type(account_class)

            %{
              code: code,
              name: name,
              account_class: account_class,
              account_type: account_type
            }
          end

        _ ->
          nil
      end
    end
  end

  defp derive_class(code) do
    case Integer.parse(code) do
      {num, _} -> div(num, 100)
      :error -> 1
    end
  end

  # Според българския сметкоплан:
  # Клас 1: Капитал и резерви (equity)
  # Клас 2: Дълготрайни активи (asset)
  # Клас 3: Материални запаси (asset)
  # Клас 4: Разчети (liability/asset - зависи от салдото, избираме liability)
  # Клас 5: Парични средства и финансови активи (asset)
  # Клас 6: Разходи (expense)
  # Клас 7: Приходи (revenue)
  # Клас 8: Несъществуващ, извънредни
  # Клас 9: Задбалансови (asset)
  defp derive_type(1), do: :equity
  defp derive_type(2), do: :asset
  defp derive_type(3), do: :asset
  defp derive_type(4), do: :liability
  defp derive_type(5), do: :asset
  defp derive_type(6), do: :expense
  defp derive_type(7), do: :revenue
  # Извънредни разходи/приходи
  defp derive_type(8), do: :expense
  # Задбалансови
  defp derive_type(9), do: :asset
  defp derive_type(_), do: :asset

  defp create_account(account_data, tenant_id) do
    attrs = %{
      "tenant_id" => tenant_id,
      "code" => account_data.code,
      "name" => account_data.name,
      "account_type" => account_data.account_type,
      "account_class" => account_data.account_class
    }

    Accounting.create_account(tenant_id, attrs)
  end
end
