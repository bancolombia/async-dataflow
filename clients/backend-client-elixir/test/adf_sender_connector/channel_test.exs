Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.ChannelTest do
  use ExUnit.Case
  import Mock
  alias AdfSenderConnector.Channel

  test "should validate input data for request" do
    assert {:error, :invalid_parameters} == Channel.exchange_credentials("dummy.channel.ref2", nil)
    assert {:error, :invalid_parameters} == Channel.exchange_credentials(nil, "some_user")
    assert {:error, :invalid_parameters} == Channel.exchange_credentials(nil, nil)
  end

  test "should exchange creds" do
    demo_response = %Finch.Response{status: 200,
      body: "{ \"channel_ref\": \"dummy.channel.ref0\", \"channel_secret\": \"yyy0\"}"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, demo_response} end
      ]}
    ]) do
      assert {:ok, %{"channel_ref" => "dummy.channel.ref0", "channel_secret" => "yyy0"}}
             = Channel.exchange_credentials("a", "b")
    end
  end

  test "should close channel" do
    demo_response = %Finch.Response{status: 202,
      body: "{ \"result\": \"Ok\" }"
    }

    with_mocks([
      {Finch, [], [
        build: fn _, _, _, _ -> {:ok, %{}} end,
        request: fn _, _ -> {:ok, demo_response} end
      ]}
    ]) do
      assert {:ok, %{"result" => "Ok"}}
             = Channel.close_channel("a")
    end
  end

end
