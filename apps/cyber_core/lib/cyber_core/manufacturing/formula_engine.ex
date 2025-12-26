defmodule CyberCore.Manufacturing.FormulaEngine do
  @moduledoc """
  Двигател за изчисляване на формули в производството.

  Поддържа безопасно изчисляване на математически изрази с променливи.

  ## Поддържани операции
    - Аритметични: +, -, *, /
    - Функции: round(), ceil(), floor(), abs(), min(), max(), if()
    - Константи: pi

  ## Примери за формули

  ### Формули за количество материал:
    - `quantity * coefficient` - базова формула
    - `quantity * coefficient * (1 + wastage_percent / 100)` - с брак
    - `if(output_quantity > 100, quantity * 0.95, quantity)` - отстъпка за големи количества
    - `round(quantity * coefficient, 2)` - закръгляване до 2 знака

  ### Формули за време:
    - `setup_time + run_time_per_unit * quantity` - базова формула
    - `setup_time + run_time_per_unit * quantity * time_coefficient` - с коефициент
    - `(setup_time + run_time_per_unit * quantity) / efficiency_coefficient` - с ефективност
    - `if(quantity > 1000, setup_time * 0.5, setup_time) + run_time_per_unit * quantity` - намален setup за големи серии
  """

  # Разрешени функции и операции
  @allowed_functions ~w(round ceil floor abs min max if)a
  @allowed_operators ~w(+ - * /)a
  @allowed_comparisons ~w(> < >= <= == !=)a

  @doc """
  Валидира формула без да я изпълнява.

  ## Връща
    - :ok - формулата е валидна
    - {:error, reason} - грешка с описание
  """
  def validate_formula(nil), do: :ok
  def validate_formula(""), do: :ok
  def validate_formula(formula) when is_binary(formula) do
    # Проверяваме за опасни конструкции
    cond do
      String.contains?(formula, ["System", "File", "IO", "Code", "Kernel", "spawn", "send", "receive"]) ->
        {:error, "Формулата съдържа забранени функции"}

      String.contains?(formula, ["__", "apply", "eval"]) ->
        {:error, "Формулата съдържа забранени конструкции"}

      String.contains?(formula, ["|>", "fn", "->", "&"]) ->
        {:error, "Формулата съдържа забранени оператори"}

      true ->
        # Пробваме да парснем формулата
        try do
          {:ok, tokens} = tokenize(formula)
          validate_tokens(tokens)
        rescue
          e -> {:error, "Невалиден синтаксис: #{Exception.message(e)}"}
        end
    end
  end

  @doc """
  Изчислява формула с дадени променливи.

  ## Параметри
    - formula: string с формулата
    - context: map с променливи (всички стойности трябва да са Decimal)

  ## Връща
    - Decimal резултат

  ## Примери

      iex> evaluate("quantity * coefficient", %{quantity: Decimal.new(10), coefficient: Decimal.new("1.5")})
      Decimal.new("15.0")
  """
  def evaluate(formula, context) when is_binary(formula) and is_map(context) do
    # Конвертираме всички стойности към float за изчисление
    float_context = Map.new(context, fn {k, v} ->
      {k, to_float(v)}
    end)

    result = do_evaluate(formula, float_context)

    # Връщаме като Decimal
    to_decimal(result)
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(n) when is_number(n), do: n * 1.0
  defp to_float(true), do: 1.0
  defp to_float(false), do: 0.0
  defp to_float(nil), do: 0.0

  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n) |> Decimal.round(6)
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(%Decimal{} = d), do: d

  defp do_evaluate(formula, context) do
    # Заместваме променливите в формулата
    replaced = Enum.reduce(context, formula, fn {key, value}, acc ->
      String.replace(acc, to_string(key), to_string(value))
    end)

    # Добавяме константи
    replaced = String.replace(replaced, "pi", to_string(:math.pi()))

    # Изчисляваме
    parse_and_evaluate(replaced)
  end

  defp parse_and_evaluate(expr) do
    # Обработваме if() функции първо
    expr = process_if_functions(expr)

    # Обработваме min/max функции
    expr = process_minmax_functions(expr)

    # Обработваме математически функции
    expr = process_math_functions(expr)

    # Изчисляваме аритметичния израз
    evaluate_arithmetic(expr)
  end

  defp process_if_functions(expr) do
    # if(condition, true_value, false_value)
    regex = ~r/if\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)/

    if Regex.match?(regex, expr) do
      Regex.replace(regex, expr, fn _, condition, true_val, false_val ->
        cond_result = evaluate_condition(String.trim(condition))
        if cond_result do
          String.trim(true_val)
        else
          String.trim(false_val)
        end
      end)
      |> process_if_functions()  # Рекурсивно за вложени if-ове
    else
      expr
    end
  end

  defp evaluate_condition(condition) do
    cond do
      String.contains?(condition, ">=") ->
        [left, right] = String.split(condition, ">=", parts: 2)
        evaluate_arithmetic(String.trim(left)) >= evaluate_arithmetic(String.trim(right))

      String.contains?(condition, "<=") ->
        [left, right] = String.split(condition, "<=", parts: 2)
        evaluate_arithmetic(String.trim(left)) <= evaluate_arithmetic(String.trim(right))

      String.contains?(condition, "!=") ->
        [left, right] = String.split(condition, "!=", parts: 2)
        evaluate_arithmetic(String.trim(left)) != evaluate_arithmetic(String.trim(right))

      String.contains?(condition, "==") ->
        [left, right] = String.split(condition, "==", parts: 2)
        evaluate_arithmetic(String.trim(left)) == evaluate_arithmetic(String.trim(right))

      String.contains?(condition, ">") ->
        [left, right] = String.split(condition, ">", parts: 2)
        evaluate_arithmetic(String.trim(left)) > evaluate_arithmetic(String.trim(right))

      String.contains?(condition, "<") ->
        [left, right] = String.split(condition, "<", parts: 2)
        evaluate_arithmetic(String.trim(left)) < evaluate_arithmetic(String.trim(right))

      true ->
        # Ако няма сравнение, интерпретираме като boolean (non-zero = true)
        evaluate_arithmetic(condition) != 0
    end
  end

  defp process_minmax_functions(expr) do
    # min(a, b) и max(a, b)
    min_regex = ~r/min\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)/
    max_regex = ~r/max\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)/

    expr
    |> then(fn e ->
      if Regex.match?(min_regex, e) do
        Regex.replace(min_regex, e, fn _, a, b ->
          val_a = evaluate_arithmetic(String.trim(a))
          val_b = evaluate_arithmetic(String.trim(b))
          to_string(min(val_a, val_b))
        end)
        |> process_minmax_functions()
      else
        e
      end
    end)
    |> then(fn e ->
      if Regex.match?(max_regex, e) do
        Regex.replace(max_regex, e, fn _, a, b ->
          val_a = evaluate_arithmetic(String.trim(a))
          val_b = evaluate_arithmetic(String.trim(b))
          to_string(max(val_a, val_b))
        end)
        |> process_minmax_functions()
      else
        e
      end
    end)
  end

  defp process_math_functions(expr) do
    expr
    |> process_round_function()
    |> process_simple_function("ceil", &Float.ceil/1)
    |> process_simple_function("floor", &Float.floor/1)
    |> process_simple_function("abs", &abs/1)
  end

  defp process_round_function(expr) do
    # round(value, precision) или round(value)
    regex = ~r/round\s*\(\s*([^,)]+)(?:\s*,\s*(\d+))?\s*\)/

    if Regex.match?(regex, expr) do
      Regex.replace(regex, expr, fn _, value, precision ->
        val = evaluate_arithmetic(String.trim(value))
        prec = if precision == "", do: 0, else: String.to_integer(precision)
        Float.round(val, prec) |> to_string()
      end)
      |> process_round_function()
    else
      expr
    end
  end

  defp process_simple_function(expr, name, fun) do
    regex = ~r/#{name}\s*\(\s*([^)]+)\s*\)/

    if Regex.match?(regex, expr) do
      Regex.replace(regex, expr, fn _, value ->
        val = evaluate_arithmetic(String.trim(value))
        fun.(val) |> to_string()
      end)
      |> process_simple_function(name, fun)
    else
      expr
    end
  end

  defp evaluate_arithmetic(expr) do
    # Използваме прост рекурсивен парсер
    expr = String.trim(expr)

    # Първо обработваме скобите
    expr = process_parentheses(expr)

    # После изчисляваме
    calculate(expr)
  end

  defp process_parentheses(expr) do
    # Намираме най-вътрешните скоби и ги изчисляваме
    regex = ~r/\(([^()]+)\)/

    if Regex.match?(regex, expr) do
      Regex.replace(regex, expr, fn _, inner ->
        calculate(inner) |> to_string()
      end)
      |> process_parentheses()
    else
      expr
    end
  end

  defp calculate(expr) do
    expr = String.trim(expr)

    # Опитваме да парснем като число
    case Float.parse(expr) do
      {num, ""} -> num
      _ -> calculate_expression(expr)
    end
  end

  defp calculate_expression(expr) do
    # Разделяме на токени, като внимаваме за отрицателни числа
    tokens = tokenize_arithmetic(expr)

    # Изчисляваме по приоритет: първо * и /, после + и -
    tokens
    |> evaluate_tokens(["*", "/"])
    |> evaluate_tokens(["+", "-"])
    |> hd()
  end

  defp tokenize_arithmetic(expr) do
    # Regex за разделяне на числа и оператори
    # Matchва числа (включително с експонента) и оператори
    Regex.scan(~r/(-?\d+\.?\d*(?:[eE][-+]?\d+)?|[\+\-\*\/])/, expr)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp evaluate_tokens(tokens, operators) do
    do_evaluate_tokens(tokens, operators, [])
  end

  defp do_evaluate_tokens([], _operators, acc), do: Enum.reverse(acc)

  defp do_evaluate_tokens([num, op, next | rest], operators, acc) when op in ["+", "-", "*", "/"] do
    if op in operators do
      result = apply_operator(parse_number(num), op, parse_number(next))
      do_evaluate_tokens([to_string(result) | rest], operators, acc)
    else
      do_evaluate_tokens([op, next | rest], operators, [num | acc])
    end
  end

  defp do_evaluate_tokens([num | rest], operators, acc) do
    do_evaluate_tokens(rest, operators, [parse_number(num) | acc])
  end

  defp parse_number(n) when is_number(n), do: n
  defp parse_number(s) when is_binary(s) do
    case Float.parse(s) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp apply_operator(a, "+", b), do: a + b
  defp apply_operator(a, "-", b), do: a - b
  defp apply_operator(a, "*", b), do: a * b
  defp apply_operator(a, "/", b) when b != 0, do: a / b
  defp apply_operator(_, "/", 0), do: 0.0

  # Токенизация за валидация
  defp tokenize(formula) do
    tokens = Regex.scan(~r/[a-zA-Z_][a-zA-Z0-9_]*|\d+\.?\d*|[+*\/().,<>=!\-]/, formula)
    |> List.flatten()
    {:ok, tokens}
  end

  defp validate_tokens(tokens) do
    # Проверяваме дали всички идентификатори са разрешени
    invalid = Enum.find(tokens, fn token ->
      cond do
        Regex.match?(~r/^\d/, token) -> false  # число
        Regex.match?(~r/^[+*\/().,<>=!\-]+$/, token) -> false  # оператор
        token in ~w(quantity coefficient wastage_percent output_quantity is_fixed) -> false
        token in ~w(setup_time run_time_per_unit wait_time move_time time_coefficient efficiency_coefficient) -> false
        token in ~w(round ceil floor abs min max if pi) -> false
        true -> true
      end
    end)

    if invalid do
      {:error, "Непозната променлива или функция: #{invalid}"}
    else
      :ok
    end
  end

  @doc """
  Връща списък с поддържаните променливи за материали.
  """
  def material_variables do
    [
      {:quantity, "Базово количество"},
      {:coefficient, "Коефициент"},
      {:wastage_percent, "Процент брак"},
      {:output_quantity, "Количество продукция"},
      {:is_fixed, "Фиксиран материал (0 или 1)"}
    ]
  end

  @doc """
  Връща списък с поддържаните променливи за операции.
  """
  def operation_variables do
    [
      {:setup_time, "Време за настройка (мин)"},
      {:run_time_per_unit, "Време за единица (мин)"},
      {:wait_time, "Време за изчакване (мин)"},
      {:move_time, "Време за преместване (мин)"},
      {:time_coefficient, "Времеви коефициент"},
      {:efficiency_coefficient, "Коефициент на ефективност"},
      {:quantity, "Количество за производство"}
    ]
  end

  @doc """
  Връща списък с поддържаните функции.
  """
  def available_functions do
    [
      {"round(x)", "Закръгляване"},
      {"round(x, n)", "Закръгляване до n знака"},
      {"ceil(x)", "Закръгляване нагоре"},
      {"floor(x)", "Закръгляване надолу"},
      {"abs(x)", "Абсолютна стойност"},
      {"min(a, b)", "Минимум"},
      {"max(a, b)", "Максимум"},
      {"if(условие, стойност_ако_да, стойност_ако_не)", "Условие"}
    ]
  end
end
