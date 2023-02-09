defmodule ChannelBridgeEx.Core.CloudEvent.Extractor do
  @moduledoc """
  Allows search and extraction of cloud event data payload
  """
  require Logger

  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Utils.JsonSearch

  @default_channel_identifier "$.data.request.headers['session-tracker']"
  @default_async_type "$.data.request.headers['async-type']"
  @default_async_target "$.data.request.headers.target"
  @default_async_operation "$.data.request.headers.operation"

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
        :channel_bridge_ex,
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
  Verifies if cloud event contains headers 'async-type', 'target' and 'operation', also checks if async-type
  is 'command'. In such case this cloud event is considered deliverable, and ADF bridge will try to route it
  to a client.
  """
  def is_async_deliverable(cloud_event) do
    with {:ok, async_type} <- extract(cloud_event, @default_async_type),
         {:ok, _} <- extract(cloud_event, @default_async_target),
         {:ok, _} <- extract(cloud_event, @default_async_operation) do
      case async_type |> String.downcase() do
        "command" -> true
        _ -> false
      end
    else
      {:error, _} -> false
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

  @doc """
  Determines if this cloud_event data payload contains an ErrorResponse json object
  """
  @spec has_error_payload(cloud_event()) :: boolean()
  def has_error_payload(cloud_event) do
    case get_in(cloud_event, [Access.key!(:data), "reply", "errors"]) do
      nil -> false
      _ -> true
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
