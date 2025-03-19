defmodule ChannelSenderEx.Persistence.RedisSupervisor do
  @moduledoc false
  alias ChannelSenderEx.Persistence.RedisConnectionProps
  use Supervisor

  def spec(args) do
    %{
      id: __MODULE__,
      type: :supervisor,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    %{
      host: host,
      hostread: host_read,
      port: port,
      username: username,
      password: password,
      ssl: ssl
    } = RedisConnectionProps.resolve_properties(args)

    common = [
      port: port,
      username: username,
      password: password,
      sync_connect: true,
      ssl: ssl,
      socket_opts: resolve_socket_opts(ssl)
    ]

    writer_opts = [common ++ [host: host, name: :redix_write]]
    reader_opts = [common ++ [host: host_read, name: :redix_read]]

    children = [
      redis_child_spec(RedixWrite, writer_opts),
      redis_child_spec(RedixRead, reader_opts)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp resolve_socket_opts(_sst = true) do
    [
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp resolve_socket_opts(_sst) do
    []
  end

  defp redis_child_spec(id, args) do
    %{
      id: id,
      type: :worker,
      start: {Redix, :start_link, args}
    }
  end
end
