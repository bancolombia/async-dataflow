defmodule ChannelSenderEx.Persistence.RedisSupervisorTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Persistence.RedisConnectionProps
  alias ChannelSenderEx.Persistence.RedisSupervisor

  setup do
    :ok
  end

  test "spec/1 returns the correct supervisor spec" do
    args = [host: "localhost", port: 6379]
    expected_spec = %{
      id: RedisSupervisor,
      type: :supervisor,
      start: {RedisSupervisor, :start_link, [args]}
    }

    assert RedisSupervisor.spec(args) == expected_spec
  end

  test "start_link/1 starts the supervisor" do
    args = [host: "localhost", port: 6379]

    with_mock Supervisor, [start_link: fn _module, _args, _opts -> {:ok, self()} end] do
      assert {:ok, pid} = RedisSupervisor.start_link(args)
      assert is_pid(pid)
    end
  end

  test "init/1 initializes the supervisor with resolved properties" do
    resolved_props = %{
      host: "localhost",
      hostread: "localhost",
      port: 6379,
      username: nil,
      password: nil,
      ssl: false
    }

    with_mocks([
      {RedisConnectionProps, [], [resolve_properties: fn _args -> resolved_props end]},
      {Redix, [], [start_link: fn _args -> {:ok, self()} end]}
    ]) do
      args = [host: "localhost", port: 6379]
      assert {:ok, _} = RedisSupervisor.init(args)
    end
  end
end
