defmodule ChannelSenderEx.Core.BoundedMap do
  @moduledoc """
  A map with a maximum size, evicting the oldest key-value pair when the limit is exceeded.
  """

  @type t :: {map(), list()}

  # Initialize a new BoundedMap
  def new, do: {%{}, []}

  def size({map, _keys}), do: map_size(map)

  @doc """
  Put a key-value pair into the map. If the key already exists, update the value.
  The oldest key-value pair is evicted when the size limit is exceeded.
  The limit is set by the `max_size` parameter, defaulting to 100.
  """
  @spec put(t, String.t, any, integer()) :: t
  def put({map, keys}, key, value, max_size \\ 100) do
    if Map.has_key?(map, key) do
      # If the key already exists, update the map without changing keys
      {Map.put(map, key, value), keys}
    else
      # Add new key-value pair
      new_map = Map.put(map, key, value)
      new_keys = [key | keys]

      # Enforce the size limit
      if map_size(new_map) > max_size do
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

  # get all keys
  def keys({_, keys}), do: keys

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

  def to_map({map, _keys}) do
    Enum.map(map, fn {k, v} -> {k, parse_data(v)} end)
    |> Enum.into(%{})
  end

  def from_map(map) do
    Enum.reduce(map, new(), fn {k, v}, acc ->
      put(acc, k, List.to_tuple(v))
    end)
  end
  def merge({map, keys}, {map2, keys2}) do
    new_map = Map.merge(map, map2)
    new_keys = keys ++ keys2
    {new_map, new_keys}
  end

  defp parse_data(data) when is_tuple(data) do
    data |> Tuple.to_list()
  end

  defp parse_data(data) do
    data
  end

end
