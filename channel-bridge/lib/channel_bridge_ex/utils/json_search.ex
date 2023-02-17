defmodule ChannelBridgeEx.Utils.JsonSearch do
  @moduledoc """
  Utilities for handling json
  """
  require Logger
  @type json_data() :: Map.t()
  @type path_to_search() :: String.t() | List

  @spec extract(json_data(), path_to_search()) :: any()
  def extract(json_data, path_to_search) when is_binary(path_to_search)do
    case ExJSONPath.eval(json_data, path_to_search) do
      {:ok, data} ->
        data
        |> List.first()

      {:error, e} ->
        Logger.error(e)
        nil
    end
  end

  def extract(json_data, path_to_search) when is_list(path_to_search) do
    Enum.map(path_to_search, fn key ->
      case extract(json_data, key) do
        nil -> "undefined"
        value -> value
      end
    end)
    |> Enum.reduce("", fn x, acc ->
      acc <> x <> "-"
    end)
    |> String.trim_trailing("-")
  end

  @spec prepare(json_data()) :: json_data()
  def prepare(data) do
    unstruct(data)
    |> Morphix.stringmorphiform!()
  end

  @spec unstruct(json_data()) :: json_data()
  def unstruct(data) do
    case Map.has_key?(data, :__struct__) do
      true -> Map.from_struct(data)
      false -> data
    end
  end
end
