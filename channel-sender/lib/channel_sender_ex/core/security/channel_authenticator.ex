defmodule ChannelSenderEx.Core.Security.ChannelAuthenticator do
  @moduledoc """
  Channel Authentication logic
  """
  alias ChannelSenderEx.Core.ChannelIDGenerator

  @type application() :: String.t()
  @type user_ref() :: String.t()
  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @spec create_channel_credentials(application(), user_ref()) :: {channel_ref(), channel_secret()}
  def create_channel_credentials(application, user_ref) do
    channel_ref = ChannelIDGenerator.generate_channel_id(application, user_ref)
    channel_secret = ChannelIDGenerator.generate_token(channel_ref, application, user_ref)
    {channel_ref, channel_secret}
  end

  @spec create_channel_credentials(channel_ref(), application(), user_ref()) :: {channel_ref(), channel_secret()}
  def create_channel_credentials(external_channel_ref, application, user_ref) do
    channel_secret = ChannelIDGenerator.generate_token(external_channel_ref, application, user_ref)
    {external_channel_ref, channel_secret}
  end

  @spec authorize_channel(channel_ref(), channel_secret()) ::
          :unauthorized | {:ok, application(), user_ref()}
  def authorize_channel(channel_ref, channel_secret) do
    case ChannelIDGenerator.verify_token(channel_ref, channel_secret) do
      {:ok, application, user_ref} ->
        {:ok, application, user_ref}

      {:error, _error_reason} ->
        :unauthorized
    end
  end

  def renew_channel_secret(channel_ref, channel_secret) do
    case authorize_channel(channel_ref, channel_secret) do
      {:ok, application, user_ref} ->
        {:ok, ChannelIDGenerator.generate_token(channel_ref, application, user_ref)}

      :unauthorized ->
        :unauthorized
    end
  end
end
