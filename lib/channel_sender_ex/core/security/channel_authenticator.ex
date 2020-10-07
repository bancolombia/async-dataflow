defmodule ChannelSenderEx.Core.Security.ChannelAuthenticator do
  @moduledoc """
  Channel Authentication logic
  """
  alias ChannelSenderEx.Core.SenderApplication
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.ChannelSupervisor

  @applications_repo Application.get_env(:channel_sender_ex, :app_repo)

  @type application() :: String.t()
  @type user_ref() :: String.t()
  @type channel_ref() :: String.t()
  @type channel_secret() :: String.t()

  @spec create_channel(application(), user_ref()) ::
          {:error, :no_app} | {channel_ref(), channel_secret()}
  def create_channel(application, user_ref) do
    {channel_ref, channel_secret} = credentials = case @applications_repo.get_application(application) do
      app = %SenderApplication{} ->
        create_channel_data_for(app, user_ref)

      {:error, :no_app} ->
        raise "It is not possible to create channel for nonexistent application"
    end
    {:ok, _pid} = ChannelSupervisor.start_channel({channel_ref, application, user_ref})
    credentials
  end

  @spec authorize_channel(channel_ref(), channel_secret()) ::
          :unauthorized | {:ok, application(), user_ref()}
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

  defp create_channel_data_for(%SenderApplication{id: app_id}, user_ref) do
    channel_ref = ChannelIDGenerator.generate_channel_id(app_id, user_ref)
    channel_secret = ChannelIDGenerator.generate_token(channel_ref, app_id, user_ref)
    {channel_ref, channel_secret}
  end
end
