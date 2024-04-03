defmodule BridgeCore.CloudEvent.ExtractorTest do
  use ExUnit.Case

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.Extractor

  @moduletag :capture_log

  setup do
    cloud_event = "{
      \"data\": {
        \"hello\": \"world\",
        \"list\": [{
          \"somekey\": \"somevalue\"
        }]
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
      Application.delete_env(:channel_bridge, :cloud_event_channel_identifier)
    end)

    %{demo_evt: cloud_event}
  end

  test "Should extract channel alias from data", %{demo_evt: demo_evt} do
    Application.put_env(
      :channel_bridge,
      :cloud_event_channel_identifier,
      ["$.subject"]
    )

    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    extracted_alias =
      cloud_event
      |> Extractor.extract_channel_alias()

    assert extracted_alias == {:ok, "foo"}
  end

  test "Should fail to extract channel alias from data", %{demo_evt: demo_evt} do
    Application.put_env(
      :channel_bridge,
      :cloud_event_channel_identifier,
      ["$.somefield"]
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
    assert Extractor.extract(cloud_event, "$.id") == {:ok, "1"}
    assert Extractor.extract(cloud_event, "$.type") == {:ok, "type1"}
    assert Extractor.extract(cloud_event, "$.unexistent") == {:error, :keynotfound}
    assert Extractor.extract(cloud_event, "$.data.hello") == {:ok, "world"}
  end

  test "Should fail to extract random data from cloud event", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)

    assert Extractor.extract(cloud_event, "$.data.reply.someunexitentkey") ==
             {:error, :keynotfound}
  end

end
