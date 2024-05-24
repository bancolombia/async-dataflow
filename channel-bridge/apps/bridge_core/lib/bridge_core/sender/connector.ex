defmodule BridgeCore.Sender.Connector do
  @moduledoc false

  require Logger

  alias AdfSenderConnector.Message

  @spec channel_registration(String.t, String.t) :: {:ok, map()} | {:error, any()}
  def channel_registration(application_ref, user_ref) do
    AdfSenderConnector.channel_registration(application_ref, user_ref)
  end

  @spec start_router_process(String.t, Keyword.t) :: :ok | {:error, any()}
  def start_router_process(channel_ref, options \\ []) do
    AdfSenderConnector.start_router_process(channel_ref, options)
  end

  @spec stop_router_process(String.t, Keyword.t) :: :ok | {:error, any()}
  def stop_router_process(channel_ref, _options \\ []) do
    AdfSenderConnector.stop_router_process(channel_ref)
  end

  @spec route_message(String.t, String.t, Message.t) ::  {:ok, map()} | {:error, any()}
  def route_message(channel_ref, event_name, protocol_msg) do
    Logger.debug("Routing message to channel: #{channel_ref}")
    AdfSenderConnector.route_message(channel_ref, event_name, protocol_msg)
  end

  @spec route_message(String.t, Message.t) ::  {:ok, map()} | {:error, any()}
  def route_message(channel_ref, protocol_msg) do
    Logger.debug("Routing message to channel: #{channel_ref}")
    AdfSenderConnector.route_message(channel_ref, nil, protocol_msg)
  end

end
