defmodule CyberCore.Repo.Migrations.CreateVatOperationCodes do
  use Ecto.Migration

  def change do
    create table(:vat_operation_codes) do
      add :code, :string, size: 10, null: false, comment: "Operation code (e.g., 1-10-1, 2-11)"
      add :register_type, :string, size: 20, null: false, comment: "purchase or sale"
      add :description, :string, size: 500, null: false, comment: "Bulgarian description"

      add :column_code, :string,
        size: 10,
        null: false,
        comment: "NAP column code (пок09, про11, etc.)"

      add :tax_rate, :decimal,
        precision: 5,
        scale: 2,
        comment: "VAT rate percentage (20.00, 9.00, 0.00)"

      add :deductible_credit_type, :string,
        size: 20,
        comment: "full, partial, none, not_applicable"

      add :vies_applicable, :boolean, default: false, comment: "Requires VIES reporting"
      add :vies_indicator, :string, size: 5, comment: "Default VIES indicator (к3, к4, к5)"
      add :is_reverse_charge, :boolean, default: false, comment: "Is reverse charge operation"

      add :allowed_subcodes, {:array, :string},
        comment: "Allowed reverse charge subcodes [01, 02]"

      add :is_active, :boolean, default: true, comment: "Is code currently active"
      add :notes, :text, comment: "Additional notes and references"

      timestamps()
    end

    create unique_index(:vat_operation_codes, [:code, :register_type])
    create index(:vat_operation_codes, [:register_type])
    create index(:vat_operation_codes, [:column_code])
    create index(:vat_operation_codes, [:is_active])

    # Populate with codes from commercial product vat_nastrojki.pdf
    execute(&populate_vat_codes/0, &depopulate_vat_codes/0)
  end

  defp populate_vat_codes do
    repo().insert_all("vat_operation_codes", [
      # ===== PURCHASE REGISTER CODES (дневник покупки) =====

      # Full deductible credit - 20% rate
      %{
        code: "1-10-1",
        register_type: "purchase",
        description: "С пълен данъчен кредит: Облагаеми доставки, внос (20%)",
        column_code: "пок09",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "full",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        code: "1-10-2",
        register_type: "purchase",
        description: "С пълен данъчен кредит: ВОП/ICE (20%)",
        column_code: "пок09",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "full",
        vies_applicable: true,
        vies_indicator: "к3",
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Full deductible credit - 9% rate
      %{
        code: "1-11",
        register_type: "purchase",
        description: "С пълен данъчен кредит: Облагаеми доставки (9%)",
        column_code: "пок10",
        tax_rate: Decimal.new("9.00"),
        deductible_credit_type: "full",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Partial deductible credit
      %{
        code: "1-12",
        register_type: "purchase",
        description: "С частичен данъчен кредит",
        column_code: "пок12",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "partial",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        notes: "Изисква ръчно въвеждане на процент приспадане",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # No deductible credit
      %{
        code: "1-14",
        register_type: "purchase",
        description: "Без право на приспадане на данъчен кредит",
        column_code: "пок14",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "none",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Import with reverse charge
      %{
        code: "1-15",
        register_type: "purchase",
        description: "Внос с данъчно задължение за получателя",
        column_code: "пок15",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "full",
        vies_applicable: false,
        is_reverse_charge: true,
        allowed_subcodes: ["01", "02"],
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # ===== SALES REGISTER CODES (дневник продажби) =====

      # Standard taxable supplies - 20%
      %{
        code: "2-11",
        register_type: "sale",
        description: "Облагаеми доставки (20%)",
        column_code: "про11",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        code: "2-11-1",
        register_type: "sale",
        description: "Облагаеми доставки с обратно начисляване - подкод 01",
        column_code: "про11",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: false,
        is_reverse_charge: true,
        allowed_subcodes: ["01"],
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        code: "2-11-2",
        register_type: "sale",
        description: "Облагаеми доставки с обратно начисляване - подкод 02",
        column_code: "про11",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: false,
        is_reverse_charge: true,
        allowed_subcodes: ["02"],
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Standard taxable supplies - 9%
      %{
        code: "2-17",
        register_type: "sale",
        description: "Облагаеми доставки (9%)",
        column_code: "про17",
        tax_rate: Decimal.new("9.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Intra-community supplies (ICE/ВОП)
      %{
        code: "2-19",
        register_type: "sale",
        description: "Вътреобщностни доставки (ВОП/ICE) (20%)",
        column_code: "про19",
        tax_rate: Decimal.new("0.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: true,
        vies_indicator: "к3",
        is_reverse_charge: false,
        is_active: true,
        notes: "Освободени доставки по чл. 7",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Intra-community acquisitions (ICS/ВОД)
      %{
        code: "2-20",
        register_type: "sale",
        description: "Вътреобщностни придобивания (ВОД/ICS) (20%)",
        column_code: "про20",
        tax_rate: Decimal.new("20.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: true,
        vies_indicator: "к3",
        is_reverse_charge: false,
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Triangular operations
      %{
        code: "2-23",
        register_type: "sale",
        description: "Тристранни операции (к4)",
        column_code: "про23",
        tax_rate: Decimal.new("0.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: true,
        vies_indicator: "к4",
        is_reverse_charge: false,
        is_active: true,
        notes: "Специален режим за тристранни операции",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Services under Art. 21(2)
      %{
        code: "2-24",
        register_type: "sale",
        description: "Услуги по чл. 21, ал. 2 (к5)",
        column_code: "про24",
        tax_rate: Decimal.new("0.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: true,
        vies_indicator: "к5",
        is_reverse_charge: false,
        is_active: true,
        notes: "Услуги, облагани в друга държава членка",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Export (0% rate)
      %{
        code: "2-25",
        register_type: "sale",
        description: "Износ (0%)",
        column_code: "про25",
        tax_rate: Decimal.new("0.00"),
        deductible_credit_type: "not_applicable",
        vies_applicable: false,
        is_reverse_charge: false,
        is_active: true,
        notes: "Освободени доставки - износ извън ЕС",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])
  end

  defp depopulate_vat_codes do
    repo().delete_all("vat_operation_codes")
  end
end
