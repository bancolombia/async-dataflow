defmodule AdfSenderConnector do
  @moduledoc """
  Client for ADF Channel Sender
  """

  require Logger

  alias AdfSenderConnector.{Credentials, Message, Router}

  @type application_ref() :: binary()
  @type user_ref() :: binary()

  @type channel_ref() :: binary()
  @type message_id() :: binary()
  @type correlation_id() :: binary()
  @type event_name() :: binary()
  @type message :: Message.t()
  @type message_data() :: iodata()

  @doc """
  Request a channel registration
  """
  @spec channel_registration(application_ref(), user_ref()) :: {:ok, map()} | {:error, any()}
  def channel_registration(application_ref, user_ref) do
    Credentials.exchange_credentials(application_ref, user_ref)
  end

  @doc """
  Request a message delivery by creating a protocol message with the data provided
  """
  @spec route_message(channel_ref(), message_id(), correlation_id(),
    message() | message_data(), event_name()) :: {:ok, map()} | {:error, any()}
  def route_message(channel_ref, event_id, correlation_id, data, event_name) do
    Router.route_message({channel_ref, event_id, correlation_id, data, event_name})
  end

  @spec route_message(message()) :: {:ok, map()} | {:error, any()}
  def route_message(message) do
    Router.route_message(message)
  end

end
