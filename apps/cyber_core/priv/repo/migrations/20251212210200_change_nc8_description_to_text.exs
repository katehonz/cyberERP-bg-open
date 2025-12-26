defmodule CyberCore.Repo.Migrations.ChangeNc8DescriptionToText do
  use Ecto.Migration

  def change do
    alter table(:saft_nc8_taric_codes) do
      modify :description_bg, :text, from: :string
    end
  end
end
