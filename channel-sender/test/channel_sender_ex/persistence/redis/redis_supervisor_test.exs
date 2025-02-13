defmodule ChannelSenderEx.Persistence.RedisSupervisorTest do
  use ExUnit.Case, async: true
  import Mock

  alias ChannelSenderEx.Persistence.RedisSupervisor
  alias ChannelSenderEx.Persistence.RedisConnectionProps

  test "start_link/1 starts the supervisor with resolved properties" do
    with_mocks([
      {RedisConnectionProps, [],
       [
         resolve_properties: fn _cfg ->
           %{
             host: "localhost",
             hostread: "localhost",
             port: 6379,
             username: nil,
             password: nil,
             ssl: false
           }
         end
       ]},
      {Redix, [],
       [
         start_link: fn _args -> {:ok, self()} end
       ]}
    ]) do
      cfg = [host: "localhost", port: "6379"]
      {:ok, pid} = RedisSupervisor.start_link(cfg)

      assert is_pid(pid)
    end
  end
end
