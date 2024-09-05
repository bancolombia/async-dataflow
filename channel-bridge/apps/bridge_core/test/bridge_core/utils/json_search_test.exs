Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.Utils.JsonSearchTest do
  use ExUnit.Case
  import Mock
  alias BridgeCore.CloudEvent
  alias BridgeCore.Utils.JsonSearch

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

  test "test search for key(s)", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)
    unstruct_cloud_event = JsonSearch.prepare(cloud_event)

    assert "invoker1" == JsonSearch.extract(unstruct_cloud_event, "$.invoker")
    assert "invoker1-source1" == JsonSearch.extract(unstruct_cloud_event, ["$.invoker", "$.source"])
    assert "somevalue" == JsonSearch.extract(unstruct_cloud_event, "$.data.list[0].somekey")
    assert [%{"somekey" => "somevalue"}] == JsonSearch.extract(unstruct_cloud_event, "$.data.list")
  end

  test "test search for non-existent key(s)", %{demo_evt: demo_evt} do
    {:ok, cloud_event} = CloudEvent.from(demo_evt)
    unstruct_cloud_event = JsonSearch.prepare(cloud_event)
    assert nil == JsonSearch.extract(unstruct_cloud_event, "$.foo")
    assert "undefined-undefined" == JsonSearch.extract(unstruct_cloud_event, ["$.foo", "$.bar"])
  end

  test "test prepare" do
    res = JsonSearch.prepare(CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h"))
    assert %{
      "data" => "h",
      "dataContentType" => "application/json",
      "id" => "e",
      "invoker" => "g",
      "source" => "c",
      "specVersion" => "a",
      "subject" => "d",
      "time" => "f",
      "type" => "b"
    } == res
  end

  test "test unstruct" do
    assert %{} == JsonSearch.unstruct(%{})
  end

  test "test handle error on extract", %{demo_evt: demo_evt} do
    with_mocks([
      {ExJSONPath, [], [
        eval: fn _a, _b -> {:error, "dummy error"} end
      ]}
    ]) do

      {:ok, cloud_event} = CloudEvent.from(demo_evt)
      unstruct_cloud_event = JsonSearch.prepare(cloud_event)

      assert nil == JsonSearch.extract(unstruct_cloud_event, "$.foo")

    end
  end
end
