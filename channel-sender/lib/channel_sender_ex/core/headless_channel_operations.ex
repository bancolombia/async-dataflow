defmodule ChannelSenderEx.Core.HeadlessChannelOperations do
  @moduledoc """
  This module provides utility functions for managing channels.
  """
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Model.CreateChannelData
  alias ChannelSenderEx.Core.ChannelWorker

  require Logger

  # Convert this operations into a Behaviour

  def create_channel(create_request) do
    with {:ok, app, user_ref} <- CreateChannelData.validate(create_request),
         {channel, secret} <- ChannelAuthenticator.create_channel_credentials(app, user_ref) do
      ChannelWorker.save_channel(channel, "no-auth")
      {:ok, channel, secret}
    end
  end

  def delete_channel(channel) do
    ChannelWorker.delete_channel(channel)
  end

  def on_connect(channel, connection_id) do
    case ChannelWorker.get_channel(channel) do
      {:ok, _data} ->
        Logger.debug(fn -> "ChannelOps: Channel #{channel} exists" end)
        ChannelWorker.save_socket_data(channel, connection_id)
        {:ok, "OK"}

      {:error, reason} ->
        Logger.error(fn -> "ChannelOps: Channel #{channel} validation error: #{inspect(reason)}" end)

        # the channel does not exist, close the connection
        Task.start(fn ->
          # must wait for the socket to be fully created in AWS, for the send data and close to work
          Process.sleep(50)
          ChannelWorker.disconnect_raw_socket(connection_id, "3008")
        end)

        {:error, "3008"}
    end
  end

  def on_message(%{"payload" => "Auth::" <> secret}, connection_id) do
    with {:ok, channel} <- ChannelWorker.get_socket(connection_id),
         {:ok, _application, _user_ref} <- ChannelAuthenticator.authorize_channel(channel, secret) do

      Logger.debug(fn -> "ChannelOps: Authorized channel [#{channel}] and socket [#{connection_id}]" end)
      # update the channel process with the socket connection id
      ChannelWorker.save_socket_data(channel, connection_id)

      {:ok, "[\"\",\"\",\"AuthOk\",\"\"]"}
    else
      _ ->
        Logger.error(fn -> "ChannelOps: Unauthorized socket [#{connection_id}]" end)
        ChannelWorker.disconnect_socket(connection_id)
        {:unauthorized, "[\"\",\"\",\"AuthFailed\",\"\"]"}
    end
  end

  def on_message(%{"payload" => "Ack::" <> message_id}, connection_id) do
    ChannelWorker.ack_message(connection_id, message_id)
    {:ok, ""}
  end

  def on_message(%{"payload" => "hb::" <> hb_seq}, _connection_id) do
    # TODO: Should we add ttl to the persistence?
    {:ok, "[\"\",#{hb_seq},\":hb\",\"\"]"}
  end

  def on_message(any, _connection_id) do
    Logger.error(fn -> "ChannelOps: Invalid message received: #{inspect(any)}" end)
    {:ok, "[\"\",\"\",\"9999\",\"\"]"}
  end

  def on_disconnect(connection_id) do
    ChannelWorker.disconnect_socket(connection_id)
  end
end
