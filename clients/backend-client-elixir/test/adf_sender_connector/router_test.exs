Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.RouterTest do
  use ExUnit.Case
  import Mock

  alias AdfSenderConnector.Message
  alias AdfSenderConnector.Router

  @moduletag :capture_log

  setup_all do

    children = [
      AdfSenderConnector.spec(),
      AdfSenderConnector.registry_spec()
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, pid} = Router.start_link({:sender_url, "http://localhost:8082"},
        [http_opts: [],
        name: "router_tests"])

    assert is_pid(pid)

    %{"process" => pid}
  end

  test "should route map message", context do

    route_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, route_response} end]}
    ]) do
      assert {:ok, %{"result" => "Ok"}} == Router.route_message(Map.fetch!(context, "process"), "my_event_name", %{})

    end

    # Process.exit(pid, :kill)
  end

  test "should route struct message", context do

    route_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, route_response} end]}
    ]) do

      msg = Message.new("bar.refX", %{}, "my_event_name")

      assert {:ok, %{"result" => "Ok"}} == Router.route_message(Map.fetch!(context, "process"), "my_event_name", msg)

    end

    # Process.exit(pid, :kill)
  end

  test "should route map message - cast", context do

    route_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, route_response} end]}
    ]) do
      assert :ok == Router.cast_route_message(Map.fetch!(context, "process"), "my_event_name", %{})

    end

    # Process.exit(pid, :kill)
  end

  test "should route struct message - cast", context do

    route_response = %HTTPoison.Response{
      status_code: 200,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {HTTPoison, [], [post: fn _url, _params, _headers, _opts -> {:ok, route_response} end]}
    ]) do

      msg = Message.new("bar.refX", %{}, "my_event_name")

      assert :ok == Router.cast_route_message(Map.fetch!(context, "process"), "my_event_name", msg)

    end

    # Process.exit(pid, :kill)
  end

end
