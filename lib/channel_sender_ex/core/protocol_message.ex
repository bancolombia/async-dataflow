defmodule ChannelSenderEx.Core.ProtocolMessage do
  @moduledoc """
  Abstracts different message representations and transform operations
  """

  @type message_id() :: String.t()
  @type event_name() :: String.t()
  @type correlation_id() :: String.t()
  @type message_data() :: iodata()
  @type message_timestamp() :: integer()
  @type t() :: {message_id(), correlation_id(), event_name(), message_data(), message_timestamp()}

  @type message_member() :: iodata()
  @opaque socket_message :: [message_member()]

  @type external_message :: %{
          message_id: message_id(),
          correlation_id: correlation_id(),
          message_data: message_data(),
          event_name: event_name()
        }

  @doc """
  Converts external message to internal representation.
  """
  @spec to_protocol_message(external_message()) :: t()
  @compile {:inline, to_protocol_message: 1}
  def to_protocol_message(%{
        message_id: message_id,
        correlation_id: correlation_id,
        message_data: message_data,
        event_name: event_name
      }) do
    {message_id, correlation_id, event_name, message_data, :os.system_time(:millisecond)}
  end

  @spec from_socket_message(socket_message()) :: t()
  @compile {:inline, from_socket_message: 1}
  def from_socket_message([message_id, correlation_id, event_name, message_data]) do
    {message_id, correlation_id, event_name, message_data, :os.system_time(:millisecond)}
  end

  @spec message_id(t()) :: message_id()
  @compile {:inline, message_id: 1}
  def message_id({message_id, _, _, _, _}), do: message_id

  @spec event_name(t()) :: event_name()
  @compile {:inline, event_name: 1}
  def event_name({_, _, event_name, _, _}), do: event_name

  @doc """
  Converts internal representation to socket representation, ready to be serialized for network transmission.
  """
  @spec to_socket_message(t()) :: socket_message()
  @compile {:inline, to_socket_message: 1}
  def to_socket_message({message_id, correlation_id, event_name, message_data, _timestamp}) do
    [message_id, correlation_id, event_name, message_data]
  end
end
