# Script for importing SAF-T Invoice Types from CSV
# Run with: mix run apps/cyber_core/priv/repo/seeds/saft_invoice_types.exs

alias CyberCore.Repo
alias CyberCore.SAFT.Nomenclature.InvoiceType

# Delete existing data (optional - remove in production)
Repo.delete_all(InvoiceType)

# Invoice types based on FILE/SAFT_BG/Nom_Invoice_Types.csv
invoice_types = [
  %{code: "01", name_bg: "Фактура", name_en: "Invoice"},
  %{code: "02", name_bg: "Дебитно известие", name_en: "Debit Note"},
  %{code: "03", name_bg: "Кредитно известие", name_en: "Credit Note"},
  %{
    code: "04",
    name_bg: "Регистър на стоки под режим складиране на стоки до поискване, изпратени или транспортирани от територията на страната до територията на друга държава членка",
    name_en: "Register of goods under call-off stock arrangement - dispatched"
  },
  %{
    code: "05",
    name_bg: "Регистър на стоки под режим складиране на стоки до поискване, получени на територията на страната",
    name_en: "Register of goods under call-off stock arrangement - received"
  },
  %{code: "07", name_bg: "Митническа декларация", name_en: "Customs Declaration"},
  %{code: "09", name_bg: "Протокол или друг документ", name_en: "Protocol or other document"},
  %{code: "11", name_bg: "Фактура - касова отчетност", name_en: "Invoice - cash accounting"},
  %{code: "12", name_bg: "Дебитно известие – касова отчетност", name_en: "Debit Note - cash accounting"},
  %{code: "13", name_bg: "Кредитно известие – касова отчетност", name_en: "Credit Note - cash accounting"},
  %{
    code: "23",
    name_bg: "Кредитно известие по чл. 126б, ал. 1 от ЗДДС",
    name_en: "Credit Note under Art. 126b, para. 1 of VAT Act"
  },
  %{
    code: "29",
    name_bg: "Протокол по чл. 126б, ал. 2 и 7 от ЗДДС",
    name_en: "Protocol under Art. 126b, para. 2 and 7 of VAT Act"
  },
  %{code: "81", name_bg: "Отчет за извършените продажби", name_en: "Report of sales"},
  %{
    code: "82",
    name_bg: "Отчет за извършените продажби при специален ред на облагане",
    name_en: "Report of sales under special taxation regime"
  },
  %{
    code: "91",
    name_bg: "Протокол за изискуемия данък по чл. 151в, ал. 3 от закона",
    name_en: "Protocol for tax due under Art. 151v, para. 3 of the Act"
  },
  %{
    code: "92",
    name_bg: "Протокол за данъчния кредит по чл. 151г, ал. 8 от закона или отчет по чл. 104ж, ал. 14",
    name_en: "Protocol for tax credit under Art. 151g, para. 8 or report under Art. 104zh, para. 14"
  },
  %{
    code: "93",
    name_bg: "Протокол за изискуемия данък по чл. 151в, ал. 7 от закона с получател по доставката лице, което не прилага специалния режим",
    name_en: "Protocol for tax due under Art. 151v, para. 7 - recipient not using special regime"
  },
  %{
    code: "94",
    name_bg: "Протокол за изискуемия данък по чл. 151в, ал. 7 от закона с получател по доставката лице, което прилага специалния режим",
    name_en: "Protocol for tax due under Art. 151v, para. 7 - recipient using special regime"
  },
  %{
    code: "95",
    name_bg: "Протокол за безвъзмездно предоставяне на хранителни стоки, за което е приложим чл. 6, ал. 4, т. 4 ЗДДС",
    name_en: "Protocol for free provision of food products under Art. 6, para. 4, item 4 of VAT Act"
  }
]

Enum.each(invoice_types, fn attrs ->
  %InvoiceType{}
  |> InvoiceType.changeset(attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Imported #{length(invoice_types)} SAF-T Invoice Types")
