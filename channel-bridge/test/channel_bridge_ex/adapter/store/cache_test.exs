defmodule ChannelBridgeEx.Adapter.Store.CacheTest do
  use ExUnit.Case, async: false

  alias ChannelBridgeEx.Adapter.Store.Cache
  alias ChannelBridgeEx.Utils.Timestamp

  @moduletag :capture_log

  import Mock

  setup do
    {:ok, pid_cache} = Cache.start_link([2000])

    on_exit(fn ->
      true = Process.exit(pid_cache, :kill)
    end)

    :ok
  end

  test "Should save element to cache" do
    {:ok, value} = Cache.put("foo1", "bar")

    assert value == "bar"
  end

  test "Should get from cache" do
    Cache.put("foo2", "bar")
    {:ok, value} = Cache.get("foo2")
    assert value == "bar"
  end

  test "Should validate expiration from cache" do
    with_mocks([
      {Timestamp, [], [has_elapsed: fn _time -> true end]},
      {Timestamp, [], [now: fn -> DateTime.utc_now() |> DateTime.to_unix(:second) end]}
    ]) do
      Cache.put("foo_exp", "bar")
      assert {:miss, :expired, "bar"} == Cache.get("foo_exp")
    end
  end

  test "Should flush cache" do
    Cache.put("foo3", "bar")
    {:ok, value} = Cache.get("foo3")
    assert value == "bar"

    assert Enum.empty?(Cache.dump()) == false

    Cache.flush()
    assert {:miss, :not_found, nil} == Cache.get("foo3")
  end
end
