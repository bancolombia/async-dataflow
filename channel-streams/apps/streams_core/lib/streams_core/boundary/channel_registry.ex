defmodule StreamsCore.Boundary.ChannelRegistry do
  @moduledoc """
  Registry abstraction to locate a channel
  """
  use Horde.Registry
  require Logger

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def init(init_arg) do
    result = [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.Registry.init()
    Logger.debug("Channel registry init #{inspect(result)}")
    result
  end

  @type channel_ref :: String.t()
  @type channel_addr :: pid()
  @spec lookup_channel_addr(channel_ref()) :: :noproc | channel_addr()
  # @compile {:inline, lookup_session_addr: 1}
  def lookup_channel_addr(channel_ref) do
    case Horde.Registry.lookup(via_tuple(channel_ref)) do
      [{pid, _}] -> pid
      [] -> :noproc
    end
  end

  # @compile {:inline, via_tuple: 1}
  def via_tuple(channel_ref), do: {:via, Registry, {__MODULE__, channel_ref}}

  defp members do
    Enum.map([Node.self() | Node.list()], &{__MODULE__, &1})
  end

end
