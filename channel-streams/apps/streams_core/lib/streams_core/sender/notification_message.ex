defmodule StreamsCore.Sender.NotificationMessage do
  defstruct ~w[channel_ref message_id correlation_id message_data event_name]a

  @moduledoc """
  Notification channel message representation
  """

  @type channel_ref() :: String.t()
  @type message_id() :: String.t()
  @type correlation_id() :: String.t()
  @type message_data() :: iodata()
  @type event_name() :: String.t()
  # @type t() :: %NotificationMessage{}

  @type external_message :: %{
          channel_ref: channel_ref(),
          message_id: message_id(),
          correlation_id: correlation_id(),
          message_data: message_data(),
          event_name: event_name()
        }

  @doc """
  Converts external message to Async Dataflow representation.
  """
  @spec from(external_message()) :: struct()
  def from(%{
        channel_ref: channel_ref,
        message_id: message_id,
        correlation_id: correlation_id,
        message_data: message_data,
        event_name: event_name
      }) do
    of(channel_ref, message_id, correlation_id, message_data, event_name)
  end

  @doc """
  Creates a simple message.
  """
  @spec of(channel_ref(), message_id(), correlation_id(), message_data(), event_name()) :: struct()
  def of(channel_ref, message_id, correlation_id, message_data, event_name) do
    %__MODULE__{
      channel_ref: channel_ref,
      message_id: message_id,
      correlation_id: correlation_id,
      message_data: message_data,
      event_name: event_name
    }
  end

  # @spec split_body(body()) :: list()
  # def split_body(body) do
  #   case is_oversized(body) do
  #     true ->
  #       chunks_of(body)
  #     _ ->
  #       [%{index: 0, chunk: body}]
  #   end
  # end

  # defp is_oversized(body) do
  #   byte_size(body) >= @max_message_size
  # end

  # defp chunks_of(body) do
  #   body
  #     |> Stream.unfold(&String.split_at(&1, @max_message_size))
  #     |> Enum.take_while(&(&1 != ""))
  #     |> Enum.reduce([], fn x, acc -> [%{index: length(acc), chunk: x} | acc] end)
  # end
end
