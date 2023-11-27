defmodule AdfSenderConnector.Message do
  @derive Jason.Encoder
  defstruct ~w[channel_ref message_id correlation_id message_data event_name]a

  @moduledoc """
  Notification message representation
  """

  @type channel_ref() :: String.t()
  @type message_id() :: String.t()
  @type correlation_id() :: String.t()
  @type message_data() :: any()
  @type event_name() :: String.t()
  @type t() :: AdfSenderConnector.Message.t()

  @doc """
  Creates a message.
  """
  @spec new(channel_ref(), message_id(), correlation_id(), message_data(), event_name()) :: t()
  def new(channel_ref, message_id, correlation_id, message_data, event_name) do
    %__MODULE__{
      channel_ref: channel_ref,
      message_id: message_id,
      correlation_id: correlation_id,
      message_data: message_data,
      event_name: event_name
    }
  end

  @doc """
  Creates a message with minimal data needed.
  """
  @spec new(channel_ref(), message_data(), event_name()) :: t()
  def new(channel_ref, message_data, event_name) do
    %__MODULE__{
      channel_ref: channel_ref,
      message_id: UUID.uuid1(),
      correlation_id: nil,
      message_data: message_data,
      event_name: event_name
    }
  end

end
