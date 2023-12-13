defmodule BridgeApi.Rest.RestHelperTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias BridgeApi.Rest.{RestHelper, ChannelRequest}
  alias BridgeCore.Channel

  @moduletag :capture_log

  import Mock

  @session_id "my-channel-876"

  setup do
    token_claims = %{
      "application-id" => "abc321",
      "authorizationCode" => "XwvMsZ",
      "channel" => "BLM",
      "documentNumber" => "1989637100",
      "documentType" => "CC",
      "exp" => 1_612_389_857_257,
      "kid" =>
        "S2Fybjphd3M6a21zOnVzLWVhc3QtMTowMDAwMDAwMDAwMDA6a2V5LzI3MmFiODJkLTA1YjYtNGNmYy04ZjlhLTVjZTNlZDU0MjAyZAAAAAAEj3SnhcQeBKy172uCWtuJF5GPpvc3xfzrS+RcBhnXtw+Km4CCBDKc2psu++LGhvphOmGJByu6zCHQmFI=",
      "scope" => "BLM"
    }

    headers = %{
      "foo" => "foo-value",
      "key1" => "key1-value",
      "sub" => @session_id,
      "bar" => "bar-value",
      "key2" => "key2-value"
    }

    params = %{
      "param1" => "hello",
      "param2" => "world"
    }

    body = %{}

    Application.put_env(:channel_bridge_ex, :request_user_identifier, ["$.req_headers.key1"])
    Application.put_env(:channel_bridge_ex, :request_app_identifier, {:lookup, "$.req_headers.foo"})
    # Application.put_env(:channel_bridge_ex, :request_channel_identifier, "$.req_headers['session-tracker']")

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :request_user_identifier)
      Application.delete_env(:channel_bridge_ex, :request_app_identifier)
      # Application.delete_env(:channel_bridge_ex, :request_channel_identifier)
    end)

    {:ok, init_args: %{claims: token_claims, headers: headers, params: params, body: body}}
  end

  test "Should create channel", %{init_args: init_args} do
    with_mocks([
      {BridgeCore, [],
       [
         start_session: fn channel ->
          new_channel = Channel.update_credentials(channel, "new_ch_ref", "new_ch_secret")
          {:ok, {new_channel, nil}}
         end
       ]}
    ]) do
      request_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.start_session(request_data)

      assert {%{
                "result" => %{
                  "alias" => @session_id,
                  "channel_ref" => "new_ch_ref",
                  "channel_secret" => "new_ch_secret"
                }
              }, 200} == response
    end
  end

  # test "Should not create channel - sup process already exists", %{init_args: init_args} do

  #   with_mocks([
  #     {BridgeCore, [],
  #      [
  #        start_session: fn channel ->
  #         new_channel = Channel.update_credentials(channel, "new_ch_ref", "new_ch_secret")
  #         {:ok, {new_channel, nil}}
  #        end
  #      ]}
  #   ]) do

  #     user_data =
  #       ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

  #     response1 = RestHelper.start_session(user_data)

  #     response2 = RestHelper.start_session(user_data)

  #     assert response2 == {%{
  #                 "errors" => [
  #                   %BridgeApi.Rest.ErrorResponse{
  #                     code: "ADF00100",
  #                     domain: "",
  #                     message: "channel already registered",
  #                     reason: "",
  #                     type: ""
  #                   }
  #                 ]
  #               }, 400}
  #   end
  # end

  test "Should not create channel - invalid request payload", %{init_args: init_args} do
    user_data =
      ChannelRequest.new(
        %{
          "foo" => "foo-value"
        },
        init_args.params,
        nil,
        init_args.claims
      )

    response = RestHelper.start_session(user_data)

    assert response ==
             {%{
                "errors" => [
                  %BridgeApi.Rest.ErrorResponse{
                    code: "ADF00102",
                    domain: "",
                    message: "invalid alias parameter",
                    reason: "",
                    type: ""
                  }
                ]
              }, 400}
  end

  test "Should not create channel - adf sender integration error", %{init_args: init_args} do
    with_mocks([
      {BridgeCore, [],
       [
         start_session: fn _channel ->
          {:error, :channel_sender_econnrefused}
         end
       ]}
    ]) do
      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.start_session(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %BridgeApi.Rest.ErrorResponse{
                      code: "ADF00105",
                      domain: "",
                      message: "ADF Sender error",
                      reason: "",
                      type: ""
                    }
                  ]
                }, 502}
    end
  end

  test "Should not create channel - adf sender integration error II", %{init_args: init_args} do
    with_mocks([
      {BridgeCore, [],
       [
         start_session: fn _channel ->
          {:error, :channel_sender_unknown_error}
         end
       ]}
    ]) do
      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.start_session(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %BridgeApi.Rest.ErrorResponse{
                      code: "ADF00105",
                      domain: "",
                      message: "ADF Sender error",
                      reason: "",
                      type: ""
                    }
                  ]
                }, 502}
    end
  end

  test "Should delete existing channel", %{init_args: init_args} do
    with_mocks([
      {BridgeCore, [],
      [
        end_session: fn _channel ->
         :ok
        end
      ]}
    ]) do
      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.close_channel(user_data)

      assert response == {%{"result" => "ok"}, 200}
    end
  end

  test "Should fail deleting channel, couldnt find alias", %{init_args: init_args} do
    user_data = ChannelRequest.new(%{}, init_args.params, nil, init_args.claims)
    response = RestHelper.close_channel(user_data)

    assert response ==
             {%{
                "errors" => [
                  %BridgeApi.Rest.ErrorResponse{
                    code: "ADF00102",
                    domain: "",
                    message: "invalid alias parameter",
                    reason: "",
                    type: ""
                  }
                ]
              }, 400}
  end

  test "Should fail deleting channel, couldnt find process", %{init_args: init_args} do
    user_data =
      ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

    with_mocks([
      {BridgeCore, [],
      [
        end_session: fn _channel ->
         {:error, :noproc}
        end
      ]}
    ]) do
      response = RestHelper.close_channel(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %BridgeApi.Rest.ErrorResponse{
                      code: "ADF00103",
                      domain: "",
                      message: "channel not found",
                      reason: "",
                      type: ""
                    }
                  ]
                }, 400}
    end
  end

  test "Should fail deleting channel, already closed", %{init_args: init_args} do
    user_data =
      ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

    with_mocks([
      {BridgeCore, [],
      [
        end_session: fn _channel ->
          {:error, :alreadyclosed}
        end
      ]}
    ]) do
      response = RestHelper.close_channel(user_data)

      assert response ==
               {%{"result" => "ok"}, 200}
    end
  end
end
