defmodule ChannelBridgeEx.Core.Auth.PassthroughAuthTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.Auth.PassthroughAuth

  @moduletag :capture_log

  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  test "Should not auth channel" do
    {:ok, msg} =
      PassthroughAuth.validate_credentials(%{
        "some-header" => "some-value"
      })

    assert %{} == msg
  end
end
