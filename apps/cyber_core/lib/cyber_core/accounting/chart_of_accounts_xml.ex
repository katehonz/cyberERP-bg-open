defmodule CyberCore.Accounting.ChartOfAccountsXML do
  @moduledoc """
  Импорт и експорт на сметкоплан в XML формат.

  XML формата е универсален шаблон без tenant_id, който може да се използва
  при създаване на нова фирма.
  """

  alias CyberCore.Repo
  alias CyberCore.Accounting.Account
  import Ecto.Query

  @doc """
  Експортира сметкоплан в XML формат.

  Връща XML string без tenant_id - готов за импорт в друга фирма.
  """
  def export(tenant_id) do
    accounts =
      from(a in Account,
        where: a.tenant_id == ^tenant_id,
        order_by: [asc: a.code],
        preload: [:parent]
      )
      |> Repo.all()

    # Build parent code map for references
    code_map = Map.new(accounts, fn a -> {a.id, a.code} end)

    accounts_xml = accounts |> Enum.map(&account_to_xml(&1, code_map)) |> Enum.join("\n")
    exported_at = DateTime.utc_now() |> DateTime.to_iso8601()

    xml_content =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" <>
      "<chart_of_accounts version=\"1.0\" exported_at=\"#{exported_at}\">\n" <>
      "  <metadata>\n" <>
      "    <name>Национален сметкоплан</name>\n" <>
      "    <country>BG</country>\n" <>
      "    <standard>НСС</standard>\n" <>
      "  </metadata>\n" <>
      "  <accounts>\n" <>
      accounts_xml <>
      "\n  </accounts>\n" <>
      "</chart_of_accounts>\n"

    {:ok, xml_content}
  end

  @doc """
  Импортира сметкоплан от XML в дадена фирма (tenant).

  Options:
    - :replace - изтрива съществуващите сметки преди импорт (default: false)
    - :skip_existing - пропуска сметки, които вече съществуват (default: true)
  """
  def import_accounts(tenant_id, xml_content, opts \\ []) do
    replace = Keyword.get(opts, :replace, false)
    skip_existing = Keyword.get(opts, :skip_existing, true)

    with {:ok, parsed} <- parse_xml(xml_content),
         {:ok, accounts_data} <- extract_accounts(parsed) do

      Repo.transaction(fn ->
        # Optionally delete existing accounts
        if replace do
          from(a in Account, where: a.tenant_id == ^tenant_id)
          |> Repo.delete_all()
        end

        # First pass: create accounts without parent references
        accounts_map =
          accounts_data
          |> Enum.reduce(%{}, fn account_data, acc ->
            case create_or_skip_account(tenant_id, account_data, skip_existing) do
              {:ok, account} -> Map.put(acc, account_data["code"], account)
              {:skip, _} -> acc
              {:error, reason} -> Repo.rollback(reason)
            end
          end)

        # Second pass: update parent references
        Enum.each(accounts_data, fn account_data ->
          if account_data["parent_code"] && account_data["parent_code"] != "" do
            case {Map.get(accounts_map, account_data["code"]),
                  Map.get(accounts_map, account_data["parent_code"])} do
              {%Account{} = child, %Account{} = parent} ->
                child
                |> Ecto.Changeset.change(%{parent_id: parent.id})
                |> Repo.update!()
              _ -> :ok
            end
          end
        end)

        %{
          imported: map_size(accounts_map),
          total: length(accounts_data)
        }
      end)
    end
  end

  @doc """
  Валидира XML структура без да импортира.
  """
  def validate(xml_content) do
    with {:ok, parsed} <- parse_xml(xml_content),
         {:ok, accounts_data} <- extract_accounts(parsed) do
      errors =
        accounts_data
        |> Enum.with_index()
        |> Enum.flat_map(fn {account, idx} ->
          validate_account_data(account, idx + 1)
        end)

      if errors == [] do
        {:ok, %{valid: true, accounts_count: length(accounts_data)}}
      else
        {:error, %{valid: false, errors: errors}}
      end
    end
  end

  # Private functions

  defp account_to_xml(account, code_map) do
    parent_code = if account.parent_id, do: Map.get(code_map, account.parent_id, ""), else: ""

    "    <account>\n" <>
    "      <code>#{escape_xml(account.code)}</code>\n" <>
    "      <name>#{escape_xml(account.name)}</name>\n" <>
    "      <standard_code>#{escape_xml(account.standard_code || "")}</standard_code>\n" <>
    "      <account_type>#{account.account_type}</account_type>\n" <>
    "      <account_class>#{account.account_class}</account_class>\n" <>
    "      <parent_code>#{escape_xml(parent_code)}</parent_code>\n" <>
    "      <level>#{account.level}</level>\n" <>
    "      <is_vat_applicable>#{account.is_vat_applicable}</is_vat_applicable>\n" <>
    "      <vat_direction>#{account.vat_direction}</vat_direction>\n" <>
    "      <is_active>#{account.is_active}</is_active>\n" <>
    "      <is_analytical>#{account.is_analytical}</is_analytical>\n" <>
    "      <supports_quantities>#{account.supports_quantities}</supports_quantities>\n" <>
    "      <default_unit>#{escape_xml(account.default_unit || "")}</default_unit>\n" <>
    "    </account>"
  end

  defp escape_xml(nil), do: ""
  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
  defp escape_xml(text), do: escape_xml(to_string(text))

  defp parse_xml(xml_content) do
    try do
      {:ok, :xmerl_scan.string(String.to_charlist(xml_content))}
    rescue
      _ -> {:error, :invalid_xml}
    catch
      :exit, _ -> {:error, :invalid_xml}
    end
  end

  defp extract_accounts({root, _}) do
    accounts =
      root
      |> xpath('//account')
      |> Enum.map(&extract_account_data/1)

    {:ok, accounts}
  end

  defp extract_account_data(account_node) do
    %{
      "code" => xpath_text(account_node, './code/text()'),
      "name" => xpath_text(account_node, './name/text()'),
      "standard_code" => xpath_text(account_node, './standard_code/text()'),
      "account_type" => xpath_text(account_node, './account_type/text()'),
      "account_class" => xpath_text(account_node, './account_class/text()'),
      "parent_code" => xpath_text(account_node, './parent_code/text()'),
      "level" => xpath_text(account_node, './level/text()'),
      "is_vat_applicable" => xpath_text(account_node, './is_vat_applicable/text()'),
      "vat_direction" => xpath_text(account_node, './vat_direction/text()'),
      "is_active" => xpath_text(account_node, './is_active/text()'),
      "is_analytical" => xpath_text(account_node, './is_analytical/text()'),
      "supports_quantities" => xpath_text(account_node, './supports_quantities/text()'),
      "default_unit" => xpath_text(account_node, './default_unit/text()')
    }
  end

  defp xpath(node, path) do
    :xmerl_xpath.string(String.to_charlist(path), node)
  end

  defp xpath_text(node, path) do
    case xpath(node, path) do
      [{:xmlText, _, _, _, text, _} | _] -> to_string(text) |> String.trim()
      _ -> ""
    end
  end

  defp create_or_skip_account(tenant_id, account_data, skip_existing) do
    code = account_data["code"]

    existing = Repo.get_by(Account, tenant_id: tenant_id, code: code)

    cond do
      existing && skip_existing ->
        {:skip, existing}

      existing && !skip_existing ->
        # Update existing
        existing
        |> Account.changeset(build_account_attrs(tenant_id, account_data))
        |> Repo.update()

      true ->
        # Create new
        %Account{}
        |> Account.changeset(build_account_attrs(tenant_id, account_data))
        |> Repo.insert()
    end
  end

  defp build_account_attrs(tenant_id, data) do
    %{
      tenant_id: tenant_id,
      code: data["code"],
      name: data["name"],
      standard_code: if(data["standard_code"] != "", do: data["standard_code"], else: data["code"]),
      account_type: parse_atom(data["account_type"], :asset),
      account_class: parse_integer(data["account_class"], 1),
      level: parse_integer(data["level"], 1),
      is_vat_applicable: parse_boolean(data["is_vat_applicable"]),
      vat_direction: parse_atom(data["vat_direction"], :none),
      is_active: parse_boolean(data["is_active"], true),
      is_analytical: parse_boolean(data["is_analytical"]),
      supports_quantities: parse_boolean(data["supports_quantities"]),
      default_unit: if(data["default_unit"] != "", do: data["default_unit"], else: nil)
    }
  end

  defp parse_atom("", default), do: default
  defp parse_atom(nil, default), do: default
  defp parse_atom(value, _default), do: String.to_atom(value)

  defp parse_integer("", default), do: default
  defp parse_integer(nil, default), do: default
  defp parse_integer(value, default) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(_, default \\ false), do: default

  defp validate_account_data(data, line) do
    errors = []

    errors = if data["code"] == "" or is_nil(data["code"]) do
      ["Line #{line}: Missing required field 'code'" | errors]
    else
      errors
    end

    errors = if data["name"] == "" or is_nil(data["name"]) do
      ["Line #{line}: Missing required field 'name'" | errors]
    else
      errors
    end

    errors = if data["account_type"] == "" or is_nil(data["account_type"]) do
      ["Line #{line}: Missing required field 'account_type'" | errors]
    else
      valid_types = ~w(asset liability equity revenue expense)
      if data["account_type"] not in valid_types do
        ["Line #{line}: Invalid account_type. Must be one of: #{Enum.join(valid_types, ", ")}" | errors]
      else
        errors
      end
    end

    errors = if data["account_class"] == "" or is_nil(data["account_class"]) do
      ["Line #{line}: Missing required field 'account_class'" | errors]
    else
      case Integer.parse(data["account_class"]) do
        {class, _} when class >= 1 and class <= 9 -> errors
        _ -> ["Line #{line}: Invalid account_class. Must be between 1 and 9" | errors]
      end
    end

    Enum.reverse(errors)
  end
end
