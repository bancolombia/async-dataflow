Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCoreTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log
  import Mock
  alias BridgeCore.{Channel, AppClient, User, CloudEvent}
  alias BridgeCore.Boundary.ChannelSupervisor
  alias BridgeCore.Boundary.ChannelRegistry

  setup_all do
    ChannelRegistry.start_link(nil)
    ChannelSupervisor.start_link(nil)
    :ok
  end

  test "Should not start app twice" do

    assert {:error, {:already_started, _}} = BridgeCore.start(:normal, [])

  end

  test "should start session" do

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref0\", \"channel_secret\": \"yyy0\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do

      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("a", AppClient.new("b", nil), User.new("c")))

      :timer.sleep(100)

      assert "a" == new_channel.channel_alias
      assert [{"dummy.channel.ref0", "yyy0"}] == new_channel.procs
      assert :ready == new_channel.status

      :timer.sleep(100)

      # try to reopen same channel
      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("a", AppClient.new("b", nil), User.new("c")))

      # assert information stills the same
      assert "a" == new_channel.channel_alias
      assert [{"dummy.channel.ref0", "yyy0"}] == new_channel.procs
      assert :ready == new_channel.status

      BridgeCore.end_session("a")

    end
  end

  test "should handle error starting session" do

    create_response = %HTTPoison.Response{
      status_code: 500,
      body: "{}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do

      err_response = BridgeCore.start_session(Channel.new("a2", AppClient.new("b", nil), User.new("c")))

      assert {:error, :channel_sender_unknown_error} == err_response

    end
  end

  test "should route message" do

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref1\", \"channel_secret\": \"yyy1\"}"
    }

    route_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"message\": \"ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn url, _params, _headers, _opts ->
        if String.ends_with?(url, "ext/channel/create") do
          {:ok, create_response}
        else
          {:ok, route_response}
        end
      end]}
    ]) do

      {:ok, {new_channel, _}} = BridgeCore.start_session(Channel.new("x", AppClient.new("y", nil), User.new("z")))

      :timer.sleep(100)

      assert "x" == new_channel.channel_alias
      assert [{"dummy.channel.ref1", "yyy1"}] == new_channel.procs
      assert :ready == new_channel.status

      route_result = BridgeCore.route_message("x", CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h", "i"))

      :timer.sleep(100)

      BridgeCore.end_session("x")
    end
  end

  test "should not route message to un-existent channel" do
    route_result = BridgeCore.route_message("y", CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h", "i"))
    assert {:error, :noproc} == route_result
  end

  test "should not close un-existent channel" do
    close_result = BridgeCore.end_session("z")
    assert {:error, :noproc} == close_result
  end

  test "should parse topology configuration default" do
    assert [k8s: [{:strategy, Cluster.Strategy.Gossip}]] == BridgeCore.topologies()
  end

  test "should parse topology configuration k8s" do

    String.to_atom("Elixir.Cluster.Strategy.Gossip")

    with_mocks([
      {BridgeHelperConfig, [], [get: fn _, _ ->
         %{
            "strategy" => "Elixir.Cluster.Strategy.Gossip",
            "config" => %{
              "mode" => ":hostname",
              "kubernetes_service_name" => "bridge"
            }
          }
      end]}
    ]) do
      assert [k8s: [{:strategy, Cluster.Strategy.Gossip}, {:config, [kubernetes_service_name: "bridge", mode: :hostname]}]]
         == BridgeCore.topologies()
    end

  end

end
