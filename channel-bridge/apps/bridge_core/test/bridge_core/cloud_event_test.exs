Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.CloudEventTest do
  use ExUnit.Case

  alias BridgeCore.CloudEvent

  @moduletag :capture_log

  setup do
    demo_event = %{
      data: %{
        "request" => %{
          "headers" => %{
            "channel" => "BLM",
            "application-id" => "abc321",
            "session-tracker" => "aaaaaa",
            "documentType" => "CC",
            "documentId" => "198961"
          },
          "body" => %{
            "say" => "Hi"
          }
        },
        "response" => %{
          "msg" => "Hello World"
        }
      },
      dataContentType: "application/json",
      id: "1",
      invoker: "invoker1",
      source: "source1",
      specVersion: "0.1",
      subject: "foo",
      time: "xxx",
      type: "type1"
    }

    demo_event_json = %{
      "data" => %{
        "request" => %{
          "headers" => %{
            "channel" => "BLM",
            "application-id" => "abc321",
            "session-tracker" => "aaaaaa",
            "documentType" => "CC",
            "documentId" => "198961",
            "async-type" => "command",
            "target" => "some-micro",
            "operation" => "cmd.name.a"
          },
          "body" => %{
            "say" => "Hi"
          }
        },
        "response" => %{
          "msg" => "Hello World"
        }
      },
      "dataContentType" => "application/json",
      "id" => "1",
      "invoker" => "invoker1",
      "source" => "source1",
      "specVersion" => "0.1",
      "subject" => "foo",
      "time" => "xxx",
      "type" => "type1"
    }

    on_exit(fn ->
      Application.delete_env(:channel_bridge, :cloud_event_channel_identifier)
    end)

    %{demo_evt: demo_event, demo_evt_json: demo_event_json}
  end

  test "Should build new CloudEvent" do
    msg = CloudEvent.new("spv1", "t2", "src3", "sub4", "A4", "A5", "A6", "A7", %{A8: "HELLO"})
    assert msg != nil
    assert "spv1" == msg.specVersion
  end

  test "Should build new CloudEvent from JSON", %{demo_evt: demo_evt} do
    {:ok, msg} = CloudEvent.from(Jason.encode!(demo_evt))
    assert msg != nil
    assert "invoker1" == msg.invoker
  end

  test "Should not build a CloudEvent from invalid JSON" do
    invalid_event = %{}
    {:error, msg, _json} = CloudEvent.from(Jason.encode!(invalid_event))

    assert msg.reason != nil

    assert msg.reason.required == [
            "data",
            "dataContentType",
            "id",
            "source",
            "specVersion",
            "subject",
            "time",
            "type"
          ]
  end

  test "Should fail build new CloudEvent from JSON" do
    {:error, err, _data} = CloudEvent.from("{}")
    assert err != nil
    assert err.reason != nil
  end

  test "Should build new CloudEvent from MAP", %{demo_evt_json: demo_evt_json} do
    {:ok, msg} = CloudEvent.from(demo_evt_json)
    assert msg != nil
    assert "invoker1" == msg.invoker
  end

  test "Should fail build new CloudEvent from MAP" do
    {:ok, msg} = CloudEvent.from(%{})
    {:error, err} = CloudEvent.validate(msg)
    assert err != nil
    assert err.reason != nil
  end

  test "Should validate cloudevent", %{demo_evt_json: demo_evt_json} do
    {:ok, msg} = CloudEvent.from(demo_evt_json)
    assert msg != nil
    assert "invoker1" == msg.invoker
  end

  test "should extract channel alias from cloud event", %{demo_evt_json: demo_evt_json} do
    {:ok, msg} = CloudEvent.from(demo_evt_json)
    assert {:ok, "foo"} == CloudEvent.extract_channel_alias(msg)
  end

  test "should extract custom value from cloud event", %{demo_evt_json: demo_evt_json} do
    {:ok, msg} = CloudEvent.from(demo_evt_json)
    assert {:ok, "some-micro"} == CloudEvent.extract(msg, "$.data.request.headers.target")
  end
end
