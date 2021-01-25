defmodule CusterDynamicTest do
  use ExUnit.Case


  alias ChannelSenderEx.Core.{ChannelSupervisor, ChannelRegistry}
  alias ChannelSenderEx.Transport.Encoders.{BinaryEncoder, JsonEncoder}
#
#
#  @moduletag :capture_log
#
#  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)
#  @registry_module Application.get_env(:channel_sender_ex, :registry_module)
#  @binary "binary_flow"
#  @json "json_flow"


  test "Should connect to socket" do
    cluster = setup_cluster()


    stop_cluster(cluster)
  end

  test "Should create channel on request" do
    body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})

    {status, _headers, body} =
      request(:post, "/ext/channel/create", [{"content-type", "application/json"}], body)

    assert 200 == status

    assert %{"channel_ref" => channel_ref, "channel_secret" => channel_secret} =
             Jason.decode!(body)
  end

  defp create_channel() do
    
  end

  defp request(verb, path, headers, body) do
    case :hackney.request(verb, "http://127.0.0.1:8071" <> path, headers, body, []) do
      {:ok, status, headers, client} ->
        {:ok, body} = :hackney.body(client)
        :hackney.close(client)
        {status, headers, body}

      {:error, _} = error ->
        error
    end
  end


  defp setup_cluster do
    Application.ensure_all_started(:channel_sender_ex)
    [n1] = start_node(:node1, 8071, 8072)
    [n2] = start_node(:node2, 8061, 8062)
    [n3] = start_node(:node3, 8051, 8052)
    members = Horde.Cluster.members(ChannelSupervisor)
    assert Enum.count(members) == 4
    [n1, n2, n3]
  end

  defp stop_cluster(cluster) do
    IO.inspect(cluster)
    LocalCluster.stop_nodes(cluster)
    Application.stop(:channel_sender_ex)
  end

  defp start_node(name, rest_port, socket_port) do
    LocalCluster.start_nodes(name, 1, [
      environment: [
        channel_sender_ex: [
          rest_port: rest_port,
          socket_port: socket_port,
        ]
      ]
    ])
  end

end
