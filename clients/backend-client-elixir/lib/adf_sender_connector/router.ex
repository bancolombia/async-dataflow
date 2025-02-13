defmodule AdfSenderConnector.Router do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/deliver_message endpoint
  """

  use AdfSenderConnector.Spec
  require Logger
  alias AdfSenderConnector.Message

  @doc """
  Requests Channel Sender to route a message  with the indicated event name.
  Internally the function will build a Message struct.
  """
  @spec route_message({channel_ref(), message_id(), correlation_id(),
    message_data(), event_name()}) :: {:ok, map()} | {:error, any()}
  def route_message({channel_ref, event_id, correlation_id, data, event_name}) do
    Message.new(channel_ref, event_id, correlation_id, data, event_name)
    |> route_message()
  end

  @spec route_message(Message.t()) :: {:ok, map()} | {:error, any()}
  def route_message(message) do
    case Message.assert_valid(message) do
      {:ok, msg} ->
        msg
        |> build_request
        |> send_post_request("/ext/channel/deliver_message")
        |> decode_response
      {:error, _reason} = e ->
        e
    end
  end

  @spec route_batch([Message.t()]) :: {:ok, map()} | {:error, any()}
  def route_batch(messages) do
    %{}
    |> Map.put("messages", Message.validate(messages))
    |> Jason.encode!
    |> send_post_request("/ext/channel/deliver_batch")
    |> decode_response
  end

  defp build_request(protocol_message) do
    Jason.encode!(Map.from_struct(protocol_message))
  end

end
