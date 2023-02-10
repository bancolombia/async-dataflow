Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.ChannelTest do
  use ExUnit.Case
  import Mock
  alias AdfSenderConnector.Channel

  @moduletag :capture_log

  setup do

    children = [
      AdfSenderConnector.spec(),
      AdfSenderConnector.registry_spec()
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

   :ok
  end

  test "should start channel process" do

    options = [http_opts: [], name: "foo"]

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"my.channel.ref0\", \"channel_secret\": \"yyy0\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do

      {:ok, pid} = Channel.start_link({:sender_url, "http://localhost:8888"}, options)
      assert is_pid(pid)
      Process.exit(pid, :normal)

    end

  end

  test "should start channel process, then should exchange credentials" do

    options = [http_opts: [], app_ref: "app", user_ref: "user1", name: "bar"]

    create_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"channel_ref\": \"my.channel.ref1\", \"channel_secret\": \"yyy1\"}"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, create_response} end]}
    ]) do

      {:ok, pid} = Channel.start_link({:sender_url, "http://localhost:8888"}, options)
      assert is_pid(pid)

      {:ok, _response} = Channel.exchange_credentials(pid)

      Process.exit(pid, :normal)
    end

  end

  # test "should handle fail to request a channel registration" do
  #   my_http_options = [
  #     timeout: 10_000, recv_timeout: 10_000, max_connections: 1000
  #   ]

  #   {:ok, pid} = Channel.start_link([name: :demo2, sender_url: "http://localhost:8082", http_opts: my_http_options])
  #   response = Channel.create_channel(pid, "a", "b")
  #   assert {:error, :channel_sender_econnrefused} == response
  #   Process.exit(pid, :kill)
  # end

end
