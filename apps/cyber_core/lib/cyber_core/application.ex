defmodule CyberCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CyberCore.Repo,
      {DNSCluster, query: Application.get_env(:cyber_core, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CyberCore.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CyberCore.Finch},
      # Start the ETS Cache server
      CyberCore.Cache.Server,
      # Start the Bank Sync Scheduler
      CyberCore.Bank.SyncScheduler
      # Start a worker by calling: CyberCore.Worker.start_link(arg)
      # {CyberCore.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CyberCore.Supervisor)
  end
end
