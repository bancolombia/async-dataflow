defmodule ChannelBridgeEx.Core.User do
  @moduledoc """
  An User representation for whom a channel is opened
  """

  alias ChannelBridgeEx.Core.Channel.ChannelRequest
  alias ChannelBridgeEx.Utils.JsonSearch

  require Logger

  @default_user_ref "default_user"

  @type id() :: String.t()
  @type channel_request() :: ChannelRequest.t()

  @type t() :: %__MODULE__{
          id: id()
        }

  @derive Jason.Encoder
  defstruct id: nil,
            name: nil

  @doc """
  creates a simple client application representation
  """
  @spec new(id()) :: t()
  def new(id) do
    %__MODULE__{
      id: id
    }
  end

  @doc """
  extract client application info from a channel request
  """
  @spec from_ch_request(channel_request()) :: {:ok, t()} | {:error, reason :: term}
  def from_ch_request(channel_request) do
    app_key =
      Application.get_env(
        :channel_bridge_ex,
        :request_user_identifier,
        ["$.req_headers['user-id']"]
      )

    {:ok, new(lookup(channel_request, app_key))}
  end

  defp lookup(request_data, key_to_search) do
    user_ref =
      request_data
      |> JsonSearch.prepare()
      |> extract(key_to_search)

    case user_ref do
      nil -> @default_user_ref <> "_" <> UUID.uuid4()
      _ -> user_ref
    end
  end

  defp extract(data, keys) when is_list(keys) do
    Enum.map(keys, fn key ->
      case extract(data, key) do
        nil -> "undefined"
        value -> value
      end
    end)
    |> Enum.reduce("", fn x, acc ->
      acc <> x <> "-"
    end)
    |> String.trim_trailing("-")
  end

  defp extract(data, keys) when is_binary(keys) do
    JsonSearch.extract(data, keys)
  end
end
