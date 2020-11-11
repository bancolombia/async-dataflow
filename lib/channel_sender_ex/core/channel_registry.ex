defmodule ChannelSenderEx.Core.ChannelRegistry do
  @moduledoc """
  Registry abstraction to locate channel
  """

  @registry_module Application.get_env(:channel_sender_ex, :registry_module)

  @type channel_ref :: String.t()
  @type channel_addr :: pid()
  @spec lookup_channel_addr(channel_ref()) :: :noproc | channel_addr()
  @compile {:inline, lookup_channel_addr: 1}
  def lookup_channel_addr(channel_ref) do
    case @registry_module.lookup(via_tuple(channel_ref)) do
      [{pid, _}] -> pid
      [] -> :noproc
    end
  end

  @compile {:inline, via_tuple: 1}
  def via_tuple(channel_ref), do: {:via, @registry_module, {__MODULE__, channel_ref}}
end
