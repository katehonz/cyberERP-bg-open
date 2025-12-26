# Script for importing SAF-T Payment Methods from CSV
# Run with: mix run apps/cyber_core/priv/repo/seeds/saft_payment_methods.exs

alias CyberCore.Repo
alias CyberCore.SAFT.Nomenclature.PaymentMethod

# Delete existing data (optional - remove in production)
Repo.delete_all(PaymentMethod)

# Payment methods based on FILE/SAFT_BG/Nom_PaymentMethod.csv
payment_methods = [
  # Cash payments
  %{
    payment_method_code: "01",
    payment_mechanism_code: "10",
    description_bg: "Пари в брой",
    description_en: "Cash"
  },

  # Offset/Compensation
  %{
    payment_method_code: "02",
    payment_mechanism_code: "97",
    description_bg: "Прихващане между контрагенти",
    description_en: "Offset between counterparts"
  },
  %{
    payment_method_code: "02",
    payment_mechanism_code: "98",
    description_bg: "Бартер",
    description_en: "Barter"
  },
  %{
    payment_method_code: "02",
    payment_mechanism_code: "99",
    description_bg: "Подотчетни лица",
    description_en: "Advances to employees"
  },

  # Non-cash payments
  %{
    payment_method_code: "03",
    payment_mechanism_code: "20",
    description_bg: "С чек",
    description_en: "By cheque"
  },
  %{
    payment_method_code: "03",
    payment_mechanism_code: "42",
    description_bg: "Плащане по банкова сметка",
    description_en: "Payment by bank account"
  },
  %{
    payment_method_code: "03",
    payment_mechanism_code: "48",
    description_bg: "Банкова карта",
    description_en: "Bank card"
  },
  %{
    payment_method_code: "03",
    payment_mechanism_code: "68",
    description_bg: "Услуги за онлайн плащане",
    description_en: "Online payment services"
  },
  %{
    payment_method_code: "03",
    payment_mechanism_code: "30",
    description_bg: "Ваучер",
    description_en: "Voucher"
  }
]

Enum.each(payment_methods, fn attrs ->
  %PaymentMethod{}
  |> PaymentMethod.changeset(attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Imported #{length(payment_methods)} SAF-T Payment Methods")
