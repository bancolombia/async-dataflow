defmodule ChannelSenderEx.Core.ChannelSupervisor do
  use DynamicSupervisor
  @moduledoc """
    Module to start supervised channels in a distributed way
  """
  require Logger

  alias ChannelSenderEx.Core.Channel

  def start_link(_) do
    res = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    Logger.info("Channel Supervisor started")
    res
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @type channel_ref :: String.t()
  @type application :: String.t()
  @type user_ref :: String.t()
  @type meta :: list()
  @type channel_init_args :: {channel_ref(), application(), user_ref(), meta()}

  @spec start_channel(channel_init_args()) :: any()
  def start_channel(args) do
    Logger.debug(fn -> "Channel Supervisor, starting channel with args: #{inspect(args)}" end)
    DynamicSupervisor.start_child(__MODULE__, {Channel, args})
  end

end
