defmodule AdfSenderConnector.Message do
  @moduledoc """
  Notification message representation
  """

  @derive Jason.Encoder
  defstruct ~w[channel_ref message_id correlation_id message_data event_name]a

  require Logger

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

  @spec assert_valid(t()) :: {:ok, t()} | {:error, :invalid_message}
  def assert_valid(message) do
    # Check if minimal fields are present and not nil
    result = message
            |> Map.from_struct
            |> Enum.all?(fn {key, value} ->
      case key do
        :message_data ->
          not is_nil(value)
        :correlation_id ->
          true
        _ ->
          is_binary(value) and value != ""
      end
    end)

    case result do
      true ->
        {:ok, message}
      false ->
        {:error, :invalid_message}
    end
  end

  @spec validate([map()]) :: [map()]
  def validate(messages) do
    Stream.take(messages, 10)
    |> Stream.filter(fn msg ->
      case assert_valid(msg) do
        {:ok, _} -> true
        {:error, _reason} ->
          Logger.warning("Discarding invalid message: #{inspect(Map.from_struct(msg))}")
          false
      end
    end)
    |> Stream.map(&Map.from_struct/1)
    |> Enum.to_list()
  end
end
