defmodule Elixirator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixiratorWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:elixirator, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Elixirator.PubSub},
      # Start a worker by calling: Elixirator.Worker.start_link(arg)
      # {Elixirator.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixiratorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elixirator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixiratorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
