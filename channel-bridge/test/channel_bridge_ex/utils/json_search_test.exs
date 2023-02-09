defmodule ChannelBridgeEx.Utils.JsonSearchTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Utils.JsonSearch

  # @moduletag :capture_log

  test "should extract data" do
    msg =
      "{
      \"data\": {
        \"request\": {
          \"headers\": {
            \"channel\": \"BLM\",
            \"application-id\": \"abc321\",
            \"session-tracker\": \"foo\",
            \"documentType\": \"CC\",
            \"documentId\": \"198961\",
            \"async-type\": \"command\",
            \"target\": \"some.ms\",
            \"operation\": \"some operation\"
          },
          \"body\": {
            \"say\": \"Hi\"
          }
        },
        \"response\": {
          \"msg\": \"Hello World\"
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"
      |> Jason.decode!()

    assert msg = JsonSearch.prepare(msg)
    assert "abc321" == JsonSearch.extract(msg, "$.data.request.headers['application-id']")
    assert nil == JsonSearch.extract(msg, "$.data.request.headers.application-id")
    assert nil == JsonSearch.extract(msg, "$.some")
  end
end
