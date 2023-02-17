defmodule ChannelBridgeEx.Utils.ClusterUtilsTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Utils.ClusterUtils

  @moduletag :capture_log

  test "should discover and connect local" do
    ClusterUtils.discover_and_connect_local()
  end

  test "should discover and connect" do
    ClusterUtils.discover_and_connect("localhost", "xxx")
  end
end
