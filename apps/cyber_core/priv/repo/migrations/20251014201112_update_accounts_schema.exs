defmodule CyberCore.Repo.Migrations.UpdateAccountsSchema do
  use Ecto.Migration

  def change do
    # Rename old columns
    rename table(:accounts), :category, to: :old_category
    rename table(:accounts), :normal_balance, to: :old_normal_balance

    # Add new columns to match the Account schema
    alter table(:accounts) do
      add :account_type, :string
      add :account_class, :integer
      add :level, :integer, default: 1
      add :is_vat_applicable, :boolean, default: false
      add :vat_direction, :string, default: "none"
      add :is_analytical, :boolean, default: false
      add :supports_quantities, :boolean, default: false
      add :default_unit, :string
      add :parent_id, references(:accounts, on_delete: :nilify_all)
    end

    # Note: After this migration, you may want to migrate data from old_category/old_normal_balance
    # to account_type/account_class, then drop the old columns in a future migration
  end
end
