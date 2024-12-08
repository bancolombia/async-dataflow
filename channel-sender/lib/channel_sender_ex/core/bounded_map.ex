defmodule ChannelSenderEx.Core.BoundedMap do
  @max_size 100

  @type t :: { map(), list() }

  # Initialize a new BoundedMap
  def new, do: {%{}, []}

  def size({map, _keys}), do: map_size(map)

  # Add a key-value pair, maintaining the max size limit
  @spec put(t, String.t, any) :: t
  def put({map, keys}, key, value) do
    if Map.has_key?(map, key) do
      # If the key already exists, update the map without changing keys
      {Map.put(map, key, value), keys}
    else
      # Add new key-value pair
      new_map = Map.put(map, key, value)
      new_keys = [key | keys]

      # Enforce the size limit
      if map_size(new_map) > @max_size do
        oldest_key = List.last(new_keys)
        {Map.delete(new_map, oldest_key), List.delete_at(new_keys, -1)}
      else
        {new_map, new_keys}
      end
    end
  end

  # Retrieve a value by key
  def get({map, _keys}, key) do
    Map.get(map, key)
  end

  # Pop a key-value pair
  def pop({map, keys}, key) do
    if Map.has_key?(map, key) do
      {value, new_map} = Map.pop(map, key)
      new_keys = List.delete(keys, key)
      {value, {new_map, new_keys}}
    else
      # If the key does not exist, return the structure unchanged
      {:noop, {map, keys}}
    end
  end

  # delete a key-value pair
  def delete({map, keys}, key) do
    if Map.has_key?(map, key) do
      new_map = Map.delete(map, key)
      new_keys = List.delete(keys, key)
      {new_map, new_keys}
    else
      # If the key does not exist, return the structure unchanged
      {map, keys}
    end
  end

  # Convert to a plain map
  def to_map({map, _keys}), do: map

  def merge({map, keys}, {map2, keys2}) do
    new_map = Map.merge(map, map2)
    new_keys = keys ++ keys2
    {new_map, new_keys}
  end

end