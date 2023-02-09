defmodule ChannelBridgeEx.Core.ErrorResponseTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.ErrorResponse

  @moduletag :capture_log

  test "Should build new Error Response" do
    er = ErrorResponse.new("reason1", "domain1", "code1", "message1", "type1")
    assert er != nil
    assert er.reason == "reason1"
    assert er.domain == "domain1"

    assert %ErrorResponse{} = ErrorResponse.new(nil, nil, nil, nil, nil)
  end
end
