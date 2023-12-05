defmodule BridgeCore.Boundary.ChannelSupervisor do
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  use Horde.DynamicSupervisor

  require Logger

  alias BridgeCore.Channel
  alias BridgeCore.Boundary.ChannelManager

  @type channel_t :: Channel.t()
  @type mutator_t :: any()
  @type spec_init_args :: tuple()
  @type ch_alias :: String.t()

  def start_link(_) do
    Horde.DynamicSupervisor.start_link(__MODULE__, [strategy: :one_for_one, shutdown: 1000], name: __MODULE__)
  end

  def init(init_arg) do
    [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.DynamicSupervisor.init()
  end

  defp members() do
    Enum.map([Node.self() | Node.list()], &{__MODULE__, &1})
  end

  @spec start_channel_process(channel_t(), mutator_t()) :: any()
  def start_channel_process(channel, mutator) do
    res = Horde.DynamicSupervisor.start_child(__MODULE__, channel_child_spec(channel, mutator))
    case res do
      {:error, {:already_started, pid}} ->
        ChannelManager.update(pid, channel)
      _ ->
        res
    end
  end

  @spec channel_child_spec(channel_t(), mutator_t()) :: any()
  # @compile {:inline, channel_child_spec: 1}
  def channel_child_spec(channel, mutator) do
    channel_child_spec(channel, mutator, via_tuple(channel.channel_alias))
  end

  @spec channel_child_spec(spec_init_args(), any()) :: any()
  # @compile {:inline, channel_child_spec: 2}
  def channel_child_spec(channel, mutator, name) do
    %{
      id: channel.channel_alias,
      start: {ChannelManager, :start_link, [{channel, mutator}, [name: name]]},
      # shutdown: RulesProvider.get(:channel_shutdown_tolerance),
      restart: :transient
    }
  end

  defp via_tuple(name) do
    {:via, Horde.Registry, {BridgeCore.Boundary.ChannelRegistry, name}}
  end

end
