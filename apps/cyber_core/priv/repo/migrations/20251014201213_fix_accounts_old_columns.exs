defmodule CyberCore.Repo.Migrations.FixAccountsOldColumns do
  use Ecto.Migration

  def change do
    # Make old columns nullable since we're using new columns now
    alter table(:accounts) do
      modify :old_category, :string, null: true
      modify :old_normal_balance, :string, null: true
      modify :metadata, :map, null: true
    end

    # Optionally, you can drop these columns entirely if you don't need them:
    # alter table(:accounts) do
    #   remove :old_category
    #   remove :old_normal_balance
    #   remove :metadata
    # end
  end
end
