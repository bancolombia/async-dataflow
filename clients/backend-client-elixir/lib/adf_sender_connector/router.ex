defmodule AdfSenderConnector.Router do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/deliver_message endpoint
  """

  use AdfSenderConnector.Spec

  alias AdfSenderConnector.Message

  @doc """
  Requests Channel Sender to route a message, with the indicated event name via the channel_ref.
  Internally the function will build a ProtocolMessage.
  """
  @spec deliver_message(pid(), channel_ref(), event_name(), any()) :: :ok | {:error, any()}
  def deliver_message(pid, channel_ref, event_name, message) when is_map(message) do
    protocol_message = Message.new(channel_ref, message, event_name)
    GenServer.call(pid, {:deliver_message, protocol_message})
  end

  @doc """
  Requests Channel Sender to route a ProtocolMessage.
  """
  @spec deliver_message(pid(), protocol_message()) :: :ok | {:error, any()}
  def deliver_message(pid, protocol_message) when is_struct(protocol_message) do
    GenServer.call(pid, {:deliver_message, protocol_message})
  end

  ##########################
  # Server Implementation  #
  ##########################

  @doc false
  def handle_call({:deliver_message, protocol_message}, _ctx, state) do

    response = build_delivery_request(protocol_message)
    |> request_deliver_msg(state)
    |> decode_response

    {:reply, response, state}
  end

  defp build_delivery_request(protocol_message) do
    Jason.encode!(Map.from_struct(protocol_message))
  end

  defp request_deliver_msg(request, state) do
    HTTPoison.post(
      Keyword.fetch!(state, :sender_url) <> "/ext/channel/deliver_message",
      request,
      [{"Content-Type", "application/json"}],
      hackney: [:insecure, pool: :sender_http_pool],
      timeout: 10_000, recv_timeout: 10_000, max_connections: 1000
    )
  end

end
