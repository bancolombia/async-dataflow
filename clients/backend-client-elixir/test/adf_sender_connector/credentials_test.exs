defmodule AdfSenderConnector.CredentialsTest do
  use ExUnit.Case
  import Mock
  alias AdfSenderConnector.Credentials

  test "should validate input data for request" do
    assert {:error, :channel_sender_bad_request} == Credentials.exchange_credentials("dummy.channel.ref2", nil)
    assert {:error, :channel_sender_bad_request} == Credentials.exchange_credentials(nil, "some_user")
    assert {:error, :channel_sender_bad_request} == Credentials.exchange_credentials(nil, nil)
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
       = Credentials.exchange_credentials("a", "b")
    end
  end

end
