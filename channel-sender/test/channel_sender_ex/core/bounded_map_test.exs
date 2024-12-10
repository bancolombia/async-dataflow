defmodule ChannelSenderEx.Core.BoundedMapTest do
  use ExUnit.Case
  alias ChannelSenderEx.Core.BoundedMap

  test "should save elements" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1", 100)
    |> BoundedMap.put("key2", "value2")

    assert BoundedMap.get(map, "key1") == "value1"
    assert BoundedMap.get(map, "key2") == "value2"
    assert BoundedMap.size(map) == 2
  end

  test "should update existing element by key" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key1", "value2")

    assert BoundedMap.get(map, "key1") == "value2"
    assert BoundedMap.size(map) == 1
  end

  test "should not persist more tan permited elements" do
    bounded_map = BoundedMap.new()
    bounded_map = Enum.reduce(1..105, bounded_map, fn i, acc ->
      BoundedMap.put(acc, "key_#{i}", "value_#{i}")
    end)
    # check if the map has only 100 elements
    assert BoundedMap.size(bounded_map) == 100
    {_, keys} = bounded_map
    # check if the first element is the 105th key
    assert Enum.at(keys, 0) == "key_105"
    # check if key_6 is the 100th element (first 5 keys were removed)
    assert Enum.at(keys, 99) == "key_6"
  end

  test "should allow popping existing elements" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key2", "value2")

    {elem, new_map} = BoundedMap.pop(map, "key1")
    assert elem == "value1"
    assert BoundedMap.size(new_map) == 1
  end

  test "should considering popping non existing elements" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key2", "value2")

    {elem, new_map} = BoundedMap.pop(map, "key3")
    assert elem == :noop
    assert BoundedMap.size(new_map) == 2
  end

  test "should allow deleting elements" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key2", "value2")

    new_map = BoundedMap.delete(map, "key1")
    assert BoundedMap.size(new_map) == 1
  end

  test "should convert to regular map" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key2", "value2")

    new_map = BoundedMap.to_map(map)
    assert is_map(new_map)
    assert Map.has_key?(new_map, "key1")
    assert Map.has_key?(new_map, "key2")
  end

  test "should allow merge" do
    map = BoundedMap.new
    |> BoundedMap.put("key1", "value1")
    |> BoundedMap.put("key2", "value2")

    map2 = BoundedMap.new
    |> BoundedMap.put("key3", "value3")
    |> BoundedMap.put("key4", "value4")

    merged = BoundedMap.merge(map, map2)
    assert BoundedMap.size(merged) == 4
  end

end
