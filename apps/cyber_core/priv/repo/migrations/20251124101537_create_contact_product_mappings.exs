defmodule CyberCore.Repo.Migrations.CreateContactProductMappings do
  use Ecto.Migration

  def change do
    create table(:contact_product_mappings) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :vendor_description, :text, null: false
      add :product_id, references(:products, on_delete: :restrict), null: false
      add :times_used, :integer, default: 1, null: false
      add :last_used_at, :utc_datetime, null: false
      add :confidence, :decimal, precision: 5, scale: 2, default: 50.0, null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    # Unique constraint: one mapping per contact + vendor_description
    create unique_index(
             :contact_product_mappings,
             [:tenant_id, :contact_id, :vendor_description],
             name: :contact_product_mappings_unique_mapping
           )

    # Index for fast lookups by contact
    create index(:contact_product_mappings, [:contact_id])

    # Index for tenant
    create index(:contact_product_mappings, [:tenant_id])

    # Index for product (to find all mappings for a product)
    create index(:contact_product_mappings, [:product_id])
  end
end
