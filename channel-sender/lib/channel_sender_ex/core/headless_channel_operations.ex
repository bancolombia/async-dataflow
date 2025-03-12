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
        # TODO: Check reserialization
        Jason.encode!("{\"result\": \"OK\"}")

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

        # TODO: Check reserialization
        Jason.encode!("{\"result\": \"4001\"}")
    end
  end

  def on_message(
        %{
          "action" => _action,
          "channel" => channel,
          "secret" => secret
        },
        connection_id
      ) do
    case ChannelAuthenticator.authorize_channel(channel, secret) do
      {:ok, _application, _user_ref} ->
        Logger.debug("Authorized channel Success #{channel}")
        # update the channel process with the socket connection id
        ChannelWorker.accept_socket(channel, connection_id)

        {:ok, "[\"\",\"AuthOK\", \"\", \"\"]"}

      :unauthorized ->
        Logger.error("Unauthorized channel #{channel}")

        Task.start(fn ->
          Process.sleep(50)
          WsConnections.close(connection_id)
        end)

        {:unauthorized, "[\"\",\"AuthFailed\", \"\", \"\"]"}
    end
  end

  def on_message(
        message = %{
          "action" => _action,
          "channel" => channel,
          "ack_message_id" => message_id
        },
        _connection_id
      ) do
    Logger.debug("Ack message #{inspect(message)}")

    ChannelWorker.ack_message(channel, message_id)

    {:ok, "[\"\",\"AckOK\", \"\", \"\"]"}
  rescue
    e ->
      Logger.error("Error ACK message : #{inspect(e)}")

      {:bad_request, "[\"\",\"AckError\", \"\", \"\"]"}
  end

  def on_disconnect(connection_id) do
    ChannelWorker.disconnect_socket(connection_id)
  end
end
