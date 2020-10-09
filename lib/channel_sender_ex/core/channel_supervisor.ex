defmodule ChannelSenderEx.Core.ChannelSupervisor do
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  alias ChannelSenderEx.Core.ChannelRegistry
  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.RulesProvider

  @supervisor_module Application.get_env(:channel_sender_ex, :channel_supervisor_module)

  @type channel_ref :: String.t()
  @type application :: String.t()
  @type user_ref :: String.t()
  @type channel_init_args :: {channel_ref(), application(), user_ref()}
  @spec start_channel(channel_init_args()) :: any()
  def start_channel(args) do
    @supervisor_module.start_child(__MODULE__, channel_child_spec(args))
  end

  @spec channel_child_spec(channel_init_args()) :: any()
  @compile {:inline, channel_child_spec: 1}
  def channel_child_spec(channel_args = {channel_ref, application, user_ref}) do
    name = ChannelRegistry.via_tuple(channel_ref)

    %{
      id: "Channel_#{channel_ref}",
      start: {Channel, :start_link, [channel_args, [name: name]]},
      shutdown: RulesProvider.get(:channel_shutdown_tolerance),
      restart: :transient
    }
  end
end
