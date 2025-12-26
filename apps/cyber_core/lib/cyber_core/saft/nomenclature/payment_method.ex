defmodule CyberCore.SAFT.Nomenclature.PaymentMethod do
  @moduledoc """
  Механизми за плащане според SAF-T България номенклатура.
  """

  # Payment Methods (Методи на плащане)
  @methods %{
    "01" => %{code: "01", name_bg: "Пари в брой", name_en: "Cash"},
    "02" => %{code: "02", name_bg: "Прихващане", name_en: "Offset"},
    "03" => %{code: "03", name_bg: "Безкасово плащане", name_en: "Non-cash payment"}
  }

  # Payment Mechanisms (Механизми на плащане)
  @mechanisms %{
    "10" => %{code: "10", name_bg: "Пари в брой", name_en: "Cash"},
    "20" => %{code: "20", name_bg: "С чек", name_en: "By check"},
    "30" => %{code: "30", name_bg: "Ваучер", name_en: "Voucher"},
    "42" => %{code: "42", name_bg: "Плащане по банкова сметка", name_en: "Bank transfer"},
    "48" => %{code: "48", name_bg: "Банкова карта", name_en: "Bank card"},
    "68" => %{code: "68", name_bg: "Услуги за онлайн плащане", name_en: "Online payment services"},
    "97" => %{code: "97", name_bg: "Прихващане между контрагенти", name_en: "Offset between counterparties"},
    "98" => %{code: "98", name_bg: "Бартер", name_en: "Barter"},
    "99" => %{code: "99", name_bg: "Подотчетни лица", name_en: "Accountable persons"}
  }

  @valid_method_codes Map.keys(@methods)
  @valid_mechanism_codes Map.keys(@mechanisms)

  @doc """
  Връща всички методи на плащане.
  """
  def all_methods, do: @methods |> Map.values() |> Enum.sort_by(& &1.code)

  @doc """
  Връща всички механизми на плащане.
  """
  def all_mechanisms, do: @mechanisms |> Map.values() |> Enum.sort_by(& &1.code)

  @doc """
  Връща всички (методи + механизми) - за показване в таблица.
  """
  def all do
    methods = Enum.map(all_methods(), &Map.put(&1, :type, "Метод"))
    mechanisms = Enum.map(all_mechanisms(), &Map.put(&1, :type, "Механизъм"))
    methods ++ mechanisms
  end

  @doc """
  Връща информация за метод на плащане.
  """
  def get_method(code) when is_binary(code), do: Map.get(@methods, code)

  @doc """
  Връща информация за механизъм на плащане.
  """
  def get_mechanism(code) when is_binary(code), do: Map.get(@mechanisms, code)

  @doc """
  Проверява дали Payment Method кодът е валиден.
  """
  def valid_method_code?(code) when is_binary(code), do: code in @valid_method_codes
  def valid_method_code?(_), do: false

  @doc """
  Проверява дали Payment Mechanism кодът е валиден.
  """
  def valid_mechanism_code?(code) when is_binary(code), do: code in @valid_mechanism_codes
  def valid_mechanism_code?(_), do: false

  @doc """
  Връща името на български за метод.
  """
  def method_name_bg(code) do
    case get_method(code) do
      nil -> nil
      m -> m.name_bg
    end
  end

  @doc """
  Връща името на български за механизъм.
  """
  def mechanism_name_bg(code) do
    case get_mechanism(code) do
      nil -> nil
      m -> m.name_bg
    end
  end
end
