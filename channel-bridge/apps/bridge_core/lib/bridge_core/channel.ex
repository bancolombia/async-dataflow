defmodule BridgeCore.Channel do
  @moduledoc """
  Abstraction for an async-dataflow-channel-sender's channel
  """

  alias BridgeCore.User
  alias BridgeCore.AppClient

  require Logger

  @type channel_alias() :: binary()
  @type application_ref() :: AppClient.t()
  @type channel_key() :: binary()
  @type channel_ref() :: binary()
  @type procs() :: list()
  @type user_ref() :: User.t()
  @type channel_secret() :: binary()
  @type datetime() :: DateTime.t()

  @type t() :: %__MODULE__{
    application_ref: application_ref(),
    channel_alias: channel_alias(),
    created_at: datetime(),
    procs: procs(),
    reason: term(),
    status: atom(),
    updated_at: datetime() | nil,
    user_ref: user_ref(),
  }

  defstruct application_ref: nil,
    channel_alias: nil,
    created_at: nil,
    procs: nil,
    reason: nil,
    status: nil,
    updated_at: nil,
    user_ref: nil

  @doc """
  creates a simple channel representation
  """
  @spec new(channel_alias(), application_ref(), user_ref()) :: t()
  def new(channel_alias, application_ref, user_ref) do
    %__MODULE__{
      application_ref: application_ref,
      channel_alias: channel_alias,
      created_at: DateTime.utc_now(),
      procs: [],
      reason: nil,
      status: :new,
      updated_at: nil,
      user_ref: user_ref,
    }
  end

  @doc """
  updates creds info provided by ADF Channel Sender
  """
  @spec update_credentials(t(), binary(), binary()) :: t()
  def update_credentials(channel, channel_ref, channel_secret) do
    %__MODULE__{
      channel
      | procs: [{channel_ref, channel_secret} | channel.procs],
        # internally this is considered 'channel redy' to route messages
        status: :ready,
        updated_at: DateTime.utc_now()
    }
  end

  @spec set_status(t(), term(), term()) :: t()
  def set_status(channel, status, reason) do
    %__MODULE__{channel | status: status, reason: reason, updated_at: DateTime.utc_now()}
  end

  @doc """
  Closing the channel logically (just changing its status here), so no more operations can be done with it inside
  ADF Bridge. ADF Channel Sender it is not notified of this action, and ADF Channel Sender handles closing
  via timeouts or socket disconection.
  """
  @spec close(t()) :: {:ok, t()} | {:error, reason :: term}
  def close(channel) do
    case channel.status do
      :closed ->
        {:ok, channel}

      _ ->
        {:ok,
         %__MODULE__{
           channel
           | procs: [],
             status: :closed,
             updated_at: DateTime.utc_now()
         }}
    end
  end

end
