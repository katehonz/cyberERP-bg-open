defmodule CyberCore.Repo do
  use Ecto.Repo,
    otp_app: :cyber_core,
    adapter: Ecto.Adapters.Postgres
end
