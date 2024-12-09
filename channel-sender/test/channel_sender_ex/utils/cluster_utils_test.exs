defmodule ChannelSenderEx.Utils.TestClusterUtils do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias ChannelSenderEx.Utils.ClusterUtils

  describe "discover_and_connect_local/0" do
    test "connects to nodes with correct format" do
      node_name = "test-node@localhost"
      :net_kernel.start([String.to_atom(node_name), :shortnames])

      log = capture_log(fn ->
        ClusterUtils.discover_and_connect_local()
      end)

      assert log =~ "Node name has the incorrect format"
    end

    test "logs warning for incorrect node name format" do
      node_name = "incorrectformat@localhost"
      :net_kernel.start([String.to_atom(node_name), :shortnames])

      log = capture_log(fn ->
        ClusterUtils.discover_and_connect_local()
      end)

      assert log =~ "Node name has the incorrect format for auto discovery"
    end
  end

  describe "discover_and_connect/2" do
    test "logs warning on EPMD error" do
      epmd_host = "invalid_host"
      prefix = "test"

      log = capture_log(fn ->
        ClusterUtils.discover_and_connect(epmd_host, prefix)
      end)

      assert log =~ "EPMD error in node discovery"
    end
  end
end
