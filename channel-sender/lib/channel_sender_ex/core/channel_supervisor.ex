defmodule ChannelSenderEx.Core.ChannelSupervisor do
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  use Horde.DynamicSupervisor
  require Logger

  alias ChannelSenderEx.Core.Channel
  alias ChannelSenderEx.Core.RulesProvider

  def start_link(_) do
    result = Horde.DynamicSupervisor.start_link(__MODULE__, [strategy: :one_for_one, shutdown: 1000], name: __MODULE__)
    Logger.debug("ChannelSupervisor: #{inspect(result)}")
    result
  end

  def init(init_arg) do
    [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  defp members do
    Enum.map([Node.self() | Node.list()], &{__MODULE__, &1})
  end

  @type channel_ref :: String.t()
  @type application :: String.t()
  @type user_ref :: String.t()
  @type channel_init_args :: {channel_ref(), application(), user_ref()}
  @spec start_channel(channel_init_args()) :: any()
  def start_channel(args) do
    Horde.DynamicSupervisor.start_child(__MODULE__, channel_child_spec(args))
  end

  @spec channel_child_spec(channel_init_args()) :: any()
  @compile {:inline, channel_child_spec: 1}
  def channel_child_spec(channel_args = {channel_ref, _application, _user_ref}) do
    channel_child_spec(channel_args, via_tuple(channel_ref))
  end

  @compile {:inline, channel_child_spec: 2}
  def channel_child_spec(channel_args = {channel_ref, _application, _user_ref}, name) do
    %{
      id: "Channel_#{channel_ref}",
      start: {Channel, :start_link, [channel_args, [name: name]]},
      shutdown: RulesProvider.get(:channel_shutdown_tolerance),
      restart: :transient
    }
  end

  defp via_tuple(name) do
    {:via, Horde.Registry, {ChannelSenderEx.Core.ChannelRegistry, name}}
  end

end
