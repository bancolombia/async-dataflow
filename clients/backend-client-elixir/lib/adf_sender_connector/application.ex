defmodule AdfSenderConnector.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Finch, name: SenderHttpClient, pools: %{
        :default => [
          count: config(:conn_pools, 1),
          size: config(:pool_size, 20),
          conn_max_idle_time: config(:conn_max_idle_time, 60_000)
        ],
      }}
    ]
    opts = [strategy: :one_for_one, name: AdfSenderConnector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec config(atom, any) :: any
  defp config(key, default) do
    Application.get_env(:adf_sender_connector, key, default)
  end
end
