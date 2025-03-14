defmodule ChannelSenderEx.Core.HeadlessChannelOperations do
  @moduledoc """
  This module provides utility functions for managing channels.
  """
  alias ChannelSenderEx.Adapter.WsConnections
  alias ChannelSenderEx.Core.Data
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator
  alias ChannelSenderEx.Model.CreateChannelData
  alias ChannelSenderEx.Persistence.ChannelPersistence
  alias ChannelSenderEx.Core.ChannelWorker

  require Logger

  # Convert this operations into a Behaviour

  def create_channel(create_request, meta \\ %{}) do
    with {:ok, app, user_ref} <- CreateChannelData.validate(create_request),
         {channel, secret} <- ChannelAuthenticator.create_channel_credentials(app, user_ref) do
      ChannelWorker.save_channel(Data.new(channel, app, user_ref, meta))
      {:ok, channel, secret}
    end
  end

  def delete_channel(channel) do
    ChannelWorker.delete_channel(channel)
  end

  def on_connect(channel, connection_id) do
    case ChannelPersistence.get_channel_data("channel_#{channel}") do
      {:ok, _data} ->
        Logger.debug("Channel #{channel} existence validation response: Channel exists")
        ChannelPersistence.save_socket_data(channel, connection_id)
        # ChannelWorker.save_socket_data(channel, connection_id)
        {:ok, "OK"}

      {:error, _} ->
        Logger.error("Channel #{channel} existence validation response: Channel does not exist")

        # the channel does not exist, close the connection
        Task.start(fn ->
          # must wait for the socket to be fully created in AWS, for the send data and close to work
          Process.sleep(50)
          WsConnections.send_data(connection_id, "[\"\",\"Error::3008\", \"\", \"\"]")
          Process.sleep(50)
          WsConnections.close(connection_id)
        end)

        {:error, "3008"}
    end
  end

  def on_message(%{"payload" => "Auth::" <> secret}, connection_id) do
    Logger.debug("Auth message received for #{connection_id}")

    with {:ok, channel} <- ChannelPersistence.get_channel_data("socket_#{connection_id}"),
         {:ok, _application, _user_ref} <- ChannelAuthenticator.authorize_channel(channel, secret) do
      Logger.debug("Authorized channel Success #{channel}")
      # update the channel process with the socket connection id
      ChannelWorker.accept_socket(channel, connection_id)

      {:ok, "[\"\",\"\",\"AuthOk\",\"\"]"}
    else
      _ ->
        Logger.error("Unauthorized socket #{connection_id}")

        Task.start(fn ->
          Process.sleep(50)
          WsConnections.close(connection_id)
        end)

        {:unauthorized, "[\"\",\"\",\"AuthFailed\",\"\"]"}
    end
  end

  def on_message(%{"payload" => "Ack::" <> message_id}, connection_id) do
    ChannelWorker.ack_message(connection_id, message_id)

    {:ok, ""}
  end

  def on_message(%{"payload" => "hb::" <> hb_seq}, connection_id) do
    # TODO: Should we add ttl to the persistence?

    {:ok, "[\"\",#{hb_seq},\":hb\",\"\"]"}
  end

  def on_message(any, _connection_id) do
    Logger.error("Invalid message received: #{inspect(any)}")

    {:ok, "[\"\",\"POC\", \"\", \"\"]"}
  end

  def on_disconnect(connection_id) do
    ChannelWorker.disconnect_socket(connection_id)
  end
end
