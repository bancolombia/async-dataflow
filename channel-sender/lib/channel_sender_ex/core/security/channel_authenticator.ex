defmodule ChannelSenderEx.Core.Security.ChannelAuthenticator do
  @moduledoc """
  Channel Authentication logic
  """
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ChannelSupervisor

  @type application() :: String.t()
  @type user_ref() :: String.t()
  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @spec create_channel(application(), user_ref()) :: {channel_ref(), channel_secret()}
  def create_channel(application, user_ref) do
    {channel_ref, _channel_secret} = credentials = create_channel_data_for(application, user_ref)
    {:ok, _pid} = ChannelSupervisor.start_channel({channel_ref, application, user_ref})
    credentials
  end

  @spec authorize_channel(channel_ref(), channel_secret()) :: :unauthorized | {:ok, application(), user_ref()}
  def authorize_channel(channel_ref, channel_secret) do
    case ChannelIDGenerator.verify_token(channel_ref, channel_secret) do
      {:ok, application, user_ref} ->
        CoreStatsCollector.event(:chan_auth, {application, user_ref, channel_ref})
        {:ok, application, user_ref}

      {:error, error_reason} ->
        CoreStatsCollector.event(:chan_forbidden, {channel_ref, error_reason})
        :unauthorized
    end
  end

  defp create_channel_data_for(app_id, user_ref) do
    channel_ref = ChannelIDGenerator.generate_channel_id(app_id, user_ref)
    channel_secret = ChannelIDGenerator.generate_token(channel_ref, app_id, user_ref)
    {channel_ref, channel_secret}
  end
end
