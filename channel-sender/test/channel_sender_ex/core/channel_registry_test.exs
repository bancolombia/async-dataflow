Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.ChannelRegistryTest do
  use ExUnit.Case, sync: true
  import Mock

  alias ChannelSenderEx.Core.ChannelRegistry
  alias Horde.Registry

  @moduletag :capture_log

  test "Should query by app" do
    with_mocks([
      {Registry, [], [
        select: fn(_, _) -> [:c.pid(0, 255, 0), :c.pid(0, 254, 0)] end
      ]}
    ]) do
      assert [_, _] = ChannelRegistry.query_by_app("app_ref") |> Enum.to_list()
    end
  end

  test "Should query by user" do
    with_mocks([
      {Registry, [], [
        select: fn(_, _) -> [:c.pid(0, 255, 0), :c.pid(0, 254, 0)] end
      ]}
    ]) do
      assert [_, _] = ChannelRegistry.query_by_user("user_ref") |> Enum.to_list()
    end
  end

end
