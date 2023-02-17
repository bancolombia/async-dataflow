defmodule ChannelBridgeEx.Core.Channel do
  @moduledoc """
  Abstraction for an async-aataflow-channel-sender channel
  """

  alias ChannelBridgeEx.Core.User
  alias ChannelBridgeEx.Core.AppClient
  alias ChannelBridgeEx.Core.Channel.ChannelRequest

  require Logger

  @type channel_alias() :: String.t()
  @type application_ref() :: AppClient.t()
  @type channel_key() :: String.t()
  @type channel_ref() :: String.t()
  @type user_ref() :: User.t()
  @type channel_secret() :: String.t()

  @type t() :: %__MODULE__{
          channel_alias: channel_alias(),
          channel_ref: channel_ref(),
          channel_secret: channel_secret(),
          application_ref: application_ref(),
          user_ref: user_ref(),
          status: atom(),
          created_at: Integer.t(),
          updated_at: Integer.t()
        }

  defstruct channel_alias: nil,
            channel_ref: nil,
            channel_secret: nil,
            application_ref: nil,
            user_ref: nil,
            status: nil,
            reason: nil,
            created_at: nil,
            updated_at: nil

  @doc """
  creates a simple channel representation
  """
  @spec new(channel_alias(), application_ref(), user_ref()) :: t()
  def new(channel_alias, application_ref, user_ref) do
    %__MODULE__{
      channel_alias: channel_alias,
      channel_ref: nil,
      channel_secret: nil,
      application_ref: application_ref,
      user_ref: user_ref,
      status: :new,
      created_at: DateTime.utc_now(),
      updated_at: nil
    }
  end

  @doc """
  creates a channel representation from a channel request
  """
  @spec new_from_request(ChannelRequest.t()) :: {:ok, t()} | {:error, reason :: term}
  def new_from_request(request_data) do
    with {:ok, channel_alias} <- ChannelRequest.extract_channel_alias(request_data),
         {:ok, app_ref} <- ChannelRequest.extract_application(request_data),
         {:ok, user_ref} <- ChannelRequest.extract_user_info(request_data) do
      {:ok, new(channel_alias, app_ref, user_ref)}
    else
      {:error, reason} = err ->
        Logger.error("Error creating channel from request: #{inspect(reason)}")
        err
    end
  end

  @doc """
  Requests ADF Channel Sender to create/register a new Channel, and creating its reference and secret
  """
  @spec open(t(), String.t(), String.t()) :: t()
  def open(channel, channel_ref, channel_secret) do
    %__MODULE__{
      channel
      | channel_ref: channel_ref,
        channel_secret: channel_secret,
        # internally this is considered 'channel open'
        status: :open,
        updated_at: DateTime.utc_now()
    }
  end

  @spec open(t(), term(), term()) :: t()
  def set_status(channel, status, reason) do
    %__MODULE__{channel | status: status, reason: reason, updated_at: DateTime.utc_now()}
  end

  @doc """
  Closing the channel locally (just changing its status), no no more operations can be done with it inside
  ADF Bridge.
  No message is delivered to ADF Channel Sender. Such closing it is not callable from the outside world, and
  ADF Channel Sender handles this event via timeouts or socket disconection.
  """
  @spec close(t()) :: {:ok, t()} | {:error, reason :: term}
  def close(channel) do
    case channel.status do
      :closed ->
        {:error, :alreadyclosed}

      :new ->
        {:error, :neveropened}

      _ ->
        {:ok,
         %__MODULE__{
           channel
           | channel_ref: nil,
             channel_secret: nil,
             status: :closed,
             updated_at: DateTime.utc_now()
         }}
    end
  end

end
