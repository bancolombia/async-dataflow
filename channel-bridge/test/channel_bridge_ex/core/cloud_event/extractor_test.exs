Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelBridgeEx.Core.CloudEvent.ExtractorTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.CloudEvent.Extractor

  @moduletag :capture_log

  setup do
    cloud_event = "{
      \"data\": {
          \"request\": {
              \"headers\": {
                  \"channel\": \"ALM\",
                  \"language_id\": \"es\",
                  \"session-tracker\": \"myAlias\"
              },
              \"body\": {
                  \"action\": \"say_hi\"
              }
          },
          \"reply\": {
              \"hello\": \"world\"
          }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"

    on_exit(fn ->
      Application.delete_env(:channel_bridge_ex, :cloud_event_channel_identifier)
    end)

    %{demo_evt: cloud_event}
  end

  test "Should extract channel alias from data", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    extracted_alias =
      cloud_event
      |> Extractor.extract_channel_alias()

    assert extracted_alias == {:ok, "myAlias"}
  end

  test "Should fail to extract channel alias from data", %{demo_evt: demo_evt} do
    Application.put_env(
      :channel_bridge_ex,
      :cloud_event_channel_identifier,
      ["$.data.request.headers['foo']"]
    )

    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    {:error, reason} =
      cloud_event
      |> Extractor.extract_channel_alias()

    assert String.starts_with?(
             reason,
             "Could not calculate channel alias. Ref data not found in cloud event"
           )
  end

  test "Should extract random data from cloud event", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    assert Extractor.extract(cloud_event, "$.data.reply.hello") == {:ok, "world"}
  end

  test "Should fail to extract random data from cloud event", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    assert Extractor.extract(cloud_event, "$.data.reply.someunexitentkey") ==
             {:error, :keynotfound}
  end

  test "Should test has no error response", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    assert false == Extractor.has_error_payload(cloud_event)
  end

  test "Should test has error response" do
    evt = "{
      \"data\": {
        \"request\": {
          \"headers\": {
            \"channel\": \"BLM\",
            \"application-id\": \"abc321\",
            \"session-tracker\": \"foo\",
            \"documentType\": \"CC\",
            \"documentId\": \"198961\"
          },
          \"body\": {
            \"say\": \"Hi\"
          }
        },
        \"reply\": {
          \"errors\": [
            {
              \"reason\": \"reason1\",
              \"domain\": \"domain1\",
              \"code\": \"code1\",
              \"message\": \"message1\",
              \"type\": \"type1\"
            }
          ]
        }
      },
      \"dataContentType\": \"application/json\",
      \"id\": \"1\",
      \"invoker\": \"invoker1\",
      \"source\": \"source1\",
      \"specVersion\": \"0.1\",
      \"subject\": \"foo\",
      \"time\": \"xxx\",
      \"type\": \"type1\"
    }"

    {:ok, cloud_event} = CloudEvent.from(evt)

    assert true == Extractor.has_error_payload(cloud_event)
  end
end
