defmodule ChannelBridgeEx.Boundary.ChannelRegistry do
  @moduledoc """
  Registry abstraction to locate a channel
  """
  alias Horde.Registry

  @type channel_ref :: String.t()
  @type channel_addr :: pid()
  @spec lookup_channel_addr(channel_ref()) :: :noproc | channel_addr()
  # @compile {:inline, lookup_session_addr: 1}
  def lookup_channel_addr(channel_ref) do
    case Registry.lookup(via_tuple(channel_ref)) do
      [{pid, _}] -> pid
      [] -> :noproc
    end
  end

  # @compile {:inline, via_tuple: 1}
  def via_tuple(channel_ref), do: {:via, Registry, {__MODULE__, channel_ref}}
end
