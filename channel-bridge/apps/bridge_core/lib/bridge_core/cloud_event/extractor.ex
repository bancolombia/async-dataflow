defmodule BridgeCore.CloudEvent.Extractor do
  @moduledoc """
  Allows search and extraction of cloud event data payload
  """
  require Logger

  alias BridgeCore.CloudEvent
  alias BridgeCore.Utils.JsonSearch

  @default_channel_identifier "$.subject"

  @type cloud_event() :: CloudEvent.t()
  @type path() :: String.t()
  @type header_value() :: String.t()

  @doc """
  searches and extracts the channel alias or channel identifier from cloud_event
  """
  @spec extract_channel_alias(cloud_event()) :: {:ok, any()} | {:error, any()}
  def extract_channel_alias(cloud_event) do

    keys_for_channel =
      Application.get_env(
        :channel_bridge,
        :cloud_event_channel_identifier,
        [@default_channel_identifier]
      )

    case Enum.empty?(keys_for_channel) do
      true ->
        {:error,
          "Could not calculate channel alias. No data configured in :cloud_event_channel_identifier"}

      false ->
        build_from(cloud_event, keys_for_channel)
        |> (fn s ->
              case String.contains?(s, "undefined") do
                true ->
                  {:error,
                    "Could not calculate channel alias. Ref data not found in cloud event: #{keys_for_channel}"}

                false ->
                  {:ok, s}
              end
            end).()
    end
  end

  @doc """
  searches and extracts json data from this cloud_event payload
  """
  @spec extract(cloud_event(), path()) :: {:ok, any()} | {:error, :keynotfound}
  def extract(cloud_event, path) do
    result = build_from(cloud_event, path)

    case result do
      "undefined" ->
        {:error, :keynotfound}

      _ ->
        {:ok, result}
    end
  end

  defp build_from(data, key) when is_binary(key) do
    build_from(data, [key])
  end

  defp build_from(data, keys) when is_list(keys) do
    extract_from(data |> JsonSearch.prepare(), keys)
  end

  defp extract_from(data, keys) do
    Enum.map(keys, fn key ->
      part = JsonSearch.extract(data, key)

      if part == nil do
        "undefined"
      else
        part
      end
    end)
    |> Enum.reduce("", fn x, acc ->
      acc <> x <> "-"
    end)
    |> String.trim_trailing("-")
  end
end
