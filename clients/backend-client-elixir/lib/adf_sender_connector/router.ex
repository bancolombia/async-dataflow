defmodule AdfSenderConnector.Router do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/deliver_message endpoint
  """

  use AdfSenderConnector.Spec

  alias AdfSenderConnector.Message

  @doc """
  Requests Channel Sender to route a message, with the indicated event name.
  Internally the function will build a Message.
  This operation does not wait for the completion of the task.
  """
  @spec cast_route_message(pid(), event_name(), any()) :: :ok | {:error, any()}
  def cast_route_message(pid, event_name, message) when is_map(message) do
    GenServer.cast(pid, {:route_message, event_name, message})
  end

  @doc """
  Requests Channel Sender to route a Message.
  This operation does not wait for the completion of the task.
  """
  @spec cast_route_message(pid(), Message.t()) :: :ok | {:error, any()}
  def cast_route_message(pid, message) when is_struct(message) do
    GenServer.cast(pid, {:route_message, message})
  end

  @doc """
  Requests Channel Sender to route a message  with the indicated event name.
  Internally the function will build a Message struct.
  """
  def route_message(pid, event_name, message) when is_map(message) do
    GenServer.call(pid, {:route_message, event_name, message})
  end

  @doc """
  Requests Channel Sender to route a Message.
  """
  def route_message(pid, message) when is_struct(message) do
    GenServer.call(pid, {:route_message, message})
  end

  ##########################
  # Server Implementation  #
  ##########################

  @doc false
  def handle_cast({:route_message, event_name, message}, state) do
    build_protocol_msg(Keyword.fetch!(state, :name), message, event_name)
    |> build_and_send(state)
    {:noreply, state}
  end

  @doc false
  def handle_cast({:route_message, protocol_message}, state) do
    %{protocol_message | channel_ref: Keyword.fetch!(state, :name)}
    |> build_and_send(state)
    {:noreply, state}
  end

  def handle_call({:route_message, event_name, message}, _from, state) do
    {:reply,
      build_protocol_msg(Keyword.fetch!(state, :name), message, event_name)
      |> build_and_send(state),
      state
    }
  end

  def handle_call({:route_message, protocol_message}, _from, state) do
    {:reply,
       %{protocol_message | channel_ref: Keyword.fetch!(state, :name)}
        |> build_and_send(state),
        state
    }
  end

  defp build_and_send(p_message, state) do
    p_message
    |> build_route_request
    |> do_route_msg(state)
    |> decode_response
  end

  defp build_protocol_msg(channel_ref, message, event_name) do
    Message.new(channel_ref, message, event_name)
  end

  defp build_route_request(protocol_message) do
    Jason.encode!(Map.from_struct(protocol_message))
  end

  defp do_route_msg(request, state) do
    HTTPoison.post(
      Keyword.fetch!(state, :sender_url) <> "/ext/channel/deliver_message",
      request,
      [{"content-type", "application/json"}],
      parse_http_opts(state)
    )
  end

end
