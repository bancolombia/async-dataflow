defmodule BridgeCoreTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log
  import Mock
  alias BridgeCore.{AppClient, Channel, CloudEvent, User}

  alias BridgeCore.Boundary.{ChannelManager, ChannelRegistry, ChannelSupervisor}

  alias BridgeCore.Sender.Connector

  test "should start session" do

    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _x -> :noproc end]},
      {Connector, [], [channel_registration: fn _, _ ->
        {:ok, %{"channel_ref" => "dummy.channel.ref0", "channel_secret" => "yyy0"}}
      end]},
      {ChannelSupervisor, [], [start_channel_process: fn _x, _y -> :ok end]},
    ]) do

      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("a", AppClient.new("b", nil), User.new("c")))

      assert "a" == new_channel.channel_alias

      {:ok, refs} = Channel.get_procs(new_channel)

      assert [{"dummy.channel.ref0", "yyy0"}] == Enum.map(refs, fn ref ->
               {ref.channel_ref, ref.channel_secret}
             end)

      assert :ready == new_channel.status
    end
  end

  test "should re-start session" do

    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: [in_series(["a"], [:noproc, :c.pid(0, 255, 0)])] ]},
      {Connector, [], [channel_registration: fn _, _ ->
        {:ok, %{"channel_ref" => "dummy.channel.ref0", "channel_secret" => "yyy0"}}
      end]},
      {ChannelSupervisor, [], [start_channel_process: fn _x, _y -> :ok end]},
      {ChannelManager, [], [get_channel_info: fn _x ->
        {:ok, {Channel.new("a", AppClient.new("b", nil), User.new("c")), nil}}
      end]},
    ]) do

      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("a", AppClient.new("b", nil), User.new("c")))

      assert "a" == new_channel.channel_alias

      {:ok, refs} = Channel.get_procs(new_channel)

      assert [{"dummy.channel.ref0", "yyy0"}] == Enum.map(refs, fn ref ->
               {ref.channel_ref, ref.channel_secret}
             end)

      assert :ready == new_channel.status

      # try to reopen same channel
      {:ok, {other_channel, _}} = BridgeCore.start_session(Channel.new("a", AppClient.new("b", nil), User.new("c")))

      # assert information stills the same
      assert new_channel.channel_alias == other_channel.channel_alias

      {:ok, refs} = Channel.get_procs(other_channel)

      assert [{"dummy.channel.ref0", "yyy0"}] == Enum.map(refs, fn ref ->
               {ref.channel_ref, ref.channel_secret}
             end)

      assert :ready == other_channel.status

    end
  end

  test "should handle error starting session" do

    with_mocks([
      {Connector, [], [channel_registration: fn _a, _b -> {:error, :channel_sender_unknown_error} end]},
      {ChannelRegistry, [], [lookup_channel_addr: fn _x -> :noproc end]},
    ]) do

      assert {:error, :channel_sender_unknown_error} ==
               BridgeCore.start_session(Channel.new("a2", AppClient.new("b2", nil), User.new("c2")))
    end
  end

  test "should route message" do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: [in_series(["x"], [:noproc, :c.pid(0, 255, 0)])] ]},
      {Connector, [], [channel_registration: fn _, _ ->
        {:ok, %{"channel_ref" => "dummy.channel.ref1", "channel_secret" => "yyy1"}}
      end]},
      {ChannelSupervisor, [], [start_channel_process: fn _x, _y -> :ok end]},
      {ChannelManager, [], [deliver_message: fn _x, _y -> :ok end]},
    ]) do

      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("x", AppClient.new("y", nil), User.new("z")))

      assert "x" == new_channel.channel_alias

      {:ok, refs} = Channel.get_procs(new_channel)

      assert [{"yyy1", "dummy.channel.ref1"}] == Enum.map(refs, fn ref ->
        {ref.channel_secret, ref.channel_ref}
      end)

      assert :ready == new_channel.status

      assert :ok == BridgeCore.route_message("x", CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h"))
    end
  end

  test "should not route message to un-existent channel" do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _x -> :noproc end] },
    ]) do

      route_result = BridgeCore.route_message("y", CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h"))
      assert {:error, :noproc} == route_result
    end
  end

  test "should close channel/session" do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _x -> :c.pid(0, 255, 0) end] },
      {ChannelManager, [], [close_channel: fn _x -> :ok end] },
    ]) do

      close_result = BridgeCore.end_session("z")
      assert :ok == close_result
    end
  end

  test "should not close un-existent channel" do
    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _x -> :noproc end] },
    ]) do

      close_result = BridgeCore.end_session("z")
      assert {:error, :noproc} == close_result
    end
  end

  test "should parse topology configuration default" do
    assert [k8s: [{:strategy, Cluster.Strategy.Gossip}]] == BridgeCore.topologies()
  end

  test "should parse topology configuration k8s" do

    _ = String.to_atom("Elixir.Cluster.Strategy.Gossip")

    with_mocks([
      {BridgeHelperConfig, [], [get: fn _, _ ->
         %{
            "strategy" => "Elixir.Cluster.Strategy.Gossip",
            "config" => %{
              "mode" => ":hostname",
              "kubernetes_service_name" => "bridge",
              "some_other_key" => 10
            }
          }
      end]}
    ]) do
      assert [k8s: [{:strategy, Cluster.Strategy.Gossip},
                {:config, [kubernetes_service_name: "bridge", mode: :hostname, some_other_key: 10]}]]
         == BridgeCore.topologies()
    end

  end

  test "should parse topology with nil configuration" do

    _ = String.to_atom("Elixir.Cluster.Strategy.Gossip")

    with_mocks([
      {BridgeHelperConfig, [], [get: fn _, _ ->
        %{
          "strategy" => "Elixir.Cluster.Strategy.Gossip",
          "config" => nil
        }
      end]}
    ]) do
      assert [k8s: [{:strategy, Cluster.Strategy.Gossip}, {:config, []}]] == BridgeCore.topologies()
    end

  end
end
