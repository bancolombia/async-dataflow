defmodule ChannelBridgeEx.Entrypoint.Rest.RestHelperTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias ChannelBridgeEx.Entrypoint.Rest.RestHelper
  alias ChannelBridgeEx.Boundary.{ChannelSupervisor, ChannelRegistry, ChannelManager}
  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  @moduletag :capture_log

  import Mock

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
      "session-tracker" => "my-channel-876",
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
      {ChannelSupervisor, [],
       [
         start_channel_process: fn _channel_ref ->
           {:ok, :c.pid(0, 250, 0)}
         end
       ]},
      {ChannelManager, [],
       [
         open_channel: fn _pid ->
           %{
             "channel_alias" => "new_ch_name",
             "channel_ref" => "new_ch_ref",
             "channel_secret" => "new_ch_secret"
           }
         end
       ]}
    ]) do
      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.start_channel(user_data)

      assert {%{
                "result" => %{
                  "channel_alias" => "new_ch_name",
                  "channel_ref" => "new_ch_ref",
                  "channel_secret" => "new_ch_secret"
                }
              }, 200} == response
    end
  end

  test "Should not create channel - sup process already exists", %{init_args: init_args} do

    with_mocks([
      {ChannelSupervisor, [],
       [start_channel_process: fn _refs ->
          {:error, {:already_started, :c.pid(0, 250, 0)}}
        end]},
        {ChannelManager, [],
        [
          open_channel: fn _pid ->
            {:error, :alreadyopen}
          end
        ]}
    ]) do

      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response2 = RestHelper.start_channel(user_data)

      assert response2 == {%{
                  "errors" => [
                    %ChannelBridgeEx.Core.ErrorResponse{
                      code: "ADF00100",
                      domain: "",
                      message: "channel already registered",
                      reason: "",
                      type: ""
                    }
                  ]
                }, 400}
    end
  end

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

    response = RestHelper.start_channel(user_data)

    assert response ==
             {%{
                "errors" => [
                  %ChannelBridgeEx.Core.ErrorResponse{
                    code: "ADF00102",
                    domain: "",
                    message: "invalid session-tracker header value",
                    reason: "",
                    type: ""
                  }
                ]
              }, 400}
  end

  test "Should not create channel - adf sender integration error", %{init_args: init_args} do
    with_mocks([
      {ChannelSupervisor, [], [start_channel_process: fn _refs -> {:ok, :c.pid(0, 250, 0)} end]},
      {ChannelManager, [], [open_channel: fn _pid -> {:error, :channel_sender_econnrefused} end]}
    ]) do
      user_data =
        ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

      response = RestHelper.start_channel(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %ChannelBridgeEx.Core.ErrorResponse{
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
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> [{:c.pid(0, 250, 0), :ok}] end]},
      {ChannelManager, [], [close_channel: fn _pid -> :ok end]}
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
                  %ChannelBridgeEx.Core.ErrorResponse{
                    code: "ADF00102",
                    domain: "",
                    message: "invalid session-tracker header value",
                    reason: "",
                    type: ""
                  }
                ]
              }, 400}
  end

  test "Should fail deleting channel, couldnt find pid", %{init_args: init_args} do
    user_data =
      ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

    with_mocks([
      {ChannelRegistry, [],
       [
         lookup_channel_addr: fn _alias ->
           :noproc
         end
       ]}
    ]) do
      response = RestHelper.close_channel(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %ChannelBridgeEx.Core.ErrorResponse{
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

  test "Should fail deleting channel, error from server", %{init_args: init_args} do
    user_data =
      ChannelRequest.new(init_args.headers, init_args.params, init_args.body, init_args.claims)

    with_mocks([
      {ChannelRegistry, [], [lookup_channel_addr: fn _ref -> [{:c.pid(0, 250, 0), :ok}] end]},
      {ChannelManager, [], [close_channel: fn _pid -> {:error, :neveropened} end]}
    ]) do
      response = RestHelper.close_channel(user_data)

      assert response ==
               {%{
                  "errors" => [
                    %ChannelBridgeEx.Core.ErrorResponse{
                      code: "ADF00104",
                      domain: "",
                      message: "channel not registered",
                      reason: "",
                      type: ""
                    }
                  ]
                }, 400}
    end
  end
end
