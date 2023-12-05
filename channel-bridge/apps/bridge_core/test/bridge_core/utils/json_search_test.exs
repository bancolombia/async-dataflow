Code.compiler_options(ignore_module_conflict: true)

defmodule BridgeCore.Utils.JsonSearchTest do
  use ExUnit.Case

  alias BridgeCore.CloudEvent
  alias BridgeCore.Utils.JsonSearch

  # @moduletag :capture_log


  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  setup do
    :ok
  end

  test "test search for key(s)" do
    cloud_event = %{
      "data" => %{"hello" => "World"},
      "dataContentType" => "application/json",
      "id" => "1",
      "invoker" => "invoker1",
      "source" => "source1",
      "specVersion" => "0.1",
      "subject" => "foo",
      "time" => "xxx",
      "type" => "type1"
    }

    assert "invoker1" == JsonSearch.extract(cloud_event, "$.invoker")
    assert "invoker1-source1" == JsonSearch.extract(cloud_event, ["$.invoker", "$.source"])
  end

  test "test search for non-existent key(s)" do
    cloud_event = %{
      "data" => %{"hello" => "World"},
      "dataContentType" => "application/json",
      "id" => "1",
      "invoker" => "invoker1",
      "source" => "source1",
      "specVersion" => "0.1",
      "subject" => "foo",
      "time" => "xxx",
      "type" => "type1"
    }

    assert nil == JsonSearch.extract(cloud_event, "$.foo")
    assert "undefined-undefined" == JsonSearch.extract(cloud_event, ["$.foo", "$.bar"])
  end

  test "test prepare" do
    res = JsonSearch.prepare(CloudEvent.new("a", "b", "c", "d", "e", "f", "g", "h", "i"))
    assert %{
      "data" => "i",
      "dataContentType" => "h",
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
end
