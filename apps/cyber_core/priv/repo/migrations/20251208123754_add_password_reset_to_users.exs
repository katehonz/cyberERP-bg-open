defmodule CyberCore.Repo.Migrations.AddPasswordResetToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reset_password_token, :string
      add :reset_password_token_expires_at, :utc_datetime
    end

    create unique_index(:users, [:reset_password_token])
  end
end
