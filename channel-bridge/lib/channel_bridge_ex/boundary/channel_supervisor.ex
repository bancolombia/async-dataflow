defmodule ChannelBridgeEx.Boundary.ChannelSupervisor do
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  alias ChannelBridgeEx.Core.Channel
  alias ChannelBridgeEx.Boundary.ChannelRegistry
  alias ChannelBridgeEx.Boundary.ChannelManager
  alias Horde.DynamicSupervisor
  # alias ChannelBridgeEx.Core.RulesProvider

  @type channel_init_args :: Channel.t()
  @type spec_init_args :: Map.t()

  @spec start_channel_process(channel_init_args()) :: any()
  def start_channel_process(channel) do
    DynamicSupervisor.start_child(__MODULE__, channel_child_spec(channel))
  end

  @spec channel_child_spec(channel_init_args()) :: any()
  # @compile {:inline, channel_child_spec: 1}
  def channel_child_spec(channel) do
    Map.new()
    |> Map.put("channel", channel)
    |> channel_child_spec(ChannelRegistry.via_tuple(channel.channel_alias))
  end

  @spec channel_child_spec(spec_init_args()) :: any()
  # @compile {:inline, channel_child_spec: 2}
  def channel_child_spec(args, name) do
    %{
      id: args["channel"].channel_alias,
      start: {ChannelManager, :start_link, [args, [name: name]]},
      # shutdown: RulesProvider.get(:channel_shutdown_tolerance),
      restart: :transient
    }
  end
end
