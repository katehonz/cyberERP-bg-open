defmodule CyberCore.Repo.Migrations.AddDetailedVatFields do
  use Ecto.Migration

  def change do
    # Add detailed VAT fields to purchase register
    alter table(:vat_purchase_register) do
      add :vat_operation_code, :string,
        size: 10,
        comment: "Detailed VAT operation code (e.g., 1-10-1, 1-11)"

      add :column_code, :string, size: 10, comment: "NAP column code (e.g., пок09, пок10, пок12)"

      add :deductible_credit_type, :string,
        size: 20,
        default: "full",
        comment: "full, partial, none, not_applicable"

      add :vies_indicator, :string, size: 5, comment: "VIES indicator: к3, к4, к5"
      add :reverse_charge_subcode, :string, size: 2, comment: "Reverse charge subcode: 01, 02"

      add :is_triangular_operation, :boolean,
        default: false,
        comment: "Triangular operation flag (к4)"

      add :is_art_21_service, :boolean,
        default: false,
        comment: "Service under Art. 21(2) flag (к5)"
    end

    # Add detailed VAT fields to sales register
    alter table(:vat_sales_register) do
      add :vat_operation_code, :string,
        size: 10,
        comment: "Detailed VAT operation code (e.g., 2-11, 2-17)"

      add :column_code, :string, size: 10, comment: "NAP column code (e.g., про11, про17, про19)"
      add :vies_indicator, :string, size: 5, comment: "VIES indicator: к3, к4, к5"
      add :reverse_charge_subcode, :string, size: 2, comment: "Reverse charge subcode: 01, 02"

      add :is_triangular_operation, :boolean,
        default: false,
        comment: "Triangular operation flag (к4)"

      add :is_art_21_service, :boolean,
        default: false,
        comment: "Service under Art. 21(2) flag (к5)"
    end

    # Create indexes for efficient querying
    create index(:vat_purchase_register, [:vat_operation_code])
    create index(:vat_purchase_register, [:column_code])
    create index(:vat_sales_register, [:vat_operation_code])
    create index(:vat_sales_register, [:column_code])
  end
end
