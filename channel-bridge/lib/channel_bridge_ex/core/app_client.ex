defmodule ChannelBridgeEx.Core.AppClient do
  @moduledoc """
  An application that uses ADF to route messages to front end
  """

  alias ChannelBridgeEx.Core.Channel.ChannelRequest
  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.CloudEvent.Extractor

  require Logger

  @default_app_ref "default_app"

  @type id() :: String.t()
  @type name() :: String.t()
  @type channel_request() :: ChannelRequest.t()
  @type cloud_event() :: CloudEvent.t()

  @type t() :: %__MODULE__{
          id: id(),
          name: name()
        }

  @derive Jason.Encoder
  defstruct id: nil,
            name: nil

  @doc """
  creates a simple client application representation
  """
  @spec new(id(), name()) :: t()
  def new(id, name) do
    %__MODULE__{
      id: id,
      name: name
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
        :request_app_identifier,
        {:fixed, @default_app_ref}
      )

    app =
      case apply_strategy(app_key, channel_request) do
        {:ok, app_id} ->
          new(app_id, "")

        {:error, err} ->
          Logger.warn(
            "missing application info in request, #{inspect(app_key)} = #{err}. Data: #{inspect(channel_request)}"
          )

          new(@default_app_ref, "")
      end

    {:ok, app}
  end

  @doc """
  extract client application info from a cloud event
  """
  @spec from_cloud_event(cloud_event()) :: {:ok, t()} | {:error, reason :: term}
  def from_cloud_event(cloud_event) do
    app_key =
      Application.get_env(
        :channel_bridge_ex,
        :cloud_event_app_identifier,
        {:fixed, @default_app_ref}
      )

    case apply_strategy(app_key, cloud_event) do
      {:ok, app_id} ->
        new(app_id, "")

      {:error, err} ->
        Logger.warn(
          "missing application info in event, #{inspect(app_key)} = #{err}. Data: #{inspect(cloud_event)}"
        )

        new(@default_app_ref, "")
    end
  end

  defp apply_strategy(config, data) do
    case config do
      {:fixed, fixed_value} ->
        # uses a fixed string value as application reference
        {:ok, fixed_value}

      {:lookup, key_to_search} ->
        # searches for a key in user data map
        Extractor.extract(data, key_to_search)

      _ ->
        {:error, "invalid config"}
    end
  end
end
