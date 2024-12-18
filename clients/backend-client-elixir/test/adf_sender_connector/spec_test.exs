Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.SpecTest do
  use ExUnit.Case
  import Mock

  defmodule FakeImplementor do
    use AdfSenderConnector.Spec, option: "testable"

  end

  setup_all do
    {:ok, pid} = Finch.start_link(name: SenderHttpClient)
    on_exit(fn -> Process.exit(pid, :normal) end)
    :ok
  end

  test "should make http failed request" do
    assert {:error, :econnrefused} = FakeImplementor.send_request(%{}, "/some_url")
  end

  test "should make http sucessful request" do
    deliver_response = %Finch.Response{
      status: 200,
      body: "{\"result\": \"Ok\"}"
    }
    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
        ]}
    ]) do
      raw_response = FakeImplementor.send_request(%{}, "/some_url")
      assert {200, "{\"result\": \"Ok\"}"} = raw_response
      assert {:ok, %{"result" => "Ok"}} = FakeImplementor.decode_response(raw_response)
    end
  end

  test "should hanle http invalid request" do
    deliver_response = %Finch.Response{
      status: 400,
      body: "{\"error\": \"invalid foo or bar\"}"
    }
    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
        ]}
    ]) do
      raw_response = FakeImplementor.send_request(%{}, "/some_url")
      assert {400, _} = raw_response
      assert {:error, :channel_sender_bad_request} = FakeImplementor.decode_response(raw_response)
    end
  end

  test "should hanle http unknown error" do
    deliver_response = %Finch.Response{
      status: 500,
      body: "{\"error\": \"opps\"}"
    }
    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, deliver_response} end
        ]}
    ]) do
      raw_response = FakeImplementor.send_request(%{}, "/some_url")
      assert {500, _} = raw_response
      assert {:error, :channel_sender_unknown_error} = FakeImplementor.decode_response(raw_response)
    end
  end

end
