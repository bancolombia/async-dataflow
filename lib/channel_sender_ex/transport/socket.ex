defmodule ChannelSenderEx.Transport.Socket do
  @moduledoc """
  Implements real time socket communications with cowboy
  """
  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(req, _opts) do
    # Authenticate websocket request, called in temporary request process
    case true do
      true ->
        {:cowboy_websocket, req, _state = [], ws_opts()}

      false ->
        req = :cowboy_req.reply(400, req)
        {:ok, req, _state = []}
    end
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    # Proper websocket initialization in websocket process
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, data}, state) do
    # [{text | binary | close | ping | pong, iodata()}]
    {_commands = [{:text, "Echo: " <> data}], state}
  end

  @impl :cowboy_websocket
  def websocket_handle(_message, state) do
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def websocket_info(_message, state) do
    {_commands = [], state}
  end

  @impl :cowboy_websocket
  def terminate(_reason, _partial_req, _state) do
    :ok
  end

  defp ws_opts() do
    %{
      idle_timeout: 60000,
      #      active_n: 5,
      #      compress: false,
      #      deflate_opts: %{},
      max_frame_size: 1024,
      # Disable in pdn
      validate_utf8: true,
      # Usefull to save space avoiding to save all request info
      req_filter: fn original_req -> original_req end
    }
  end
end
