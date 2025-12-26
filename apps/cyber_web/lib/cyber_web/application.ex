defmodule CyberWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CyberWeb.Telemetry,
      # Start a worker by calling: CyberWeb.Worker.start_link(arg)
      # {CyberWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      CyberWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CyberWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CyberWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
