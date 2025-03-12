defmodule ChannelSenderEx.Core.MessageProcessRegistry do
  @moduledoc """
  Registry abstraction to locate channel
  """
  use Horde.Registry
  require Logger

  @type channel_ref :: String.t()
  @type channel_addr :: pid()

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def init(init_arg) do
    result = [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.Registry.init()
    Logger.debug("Message process registry init #{inspect(result)}")
    result
  end

  @compile {:inline, via_tuple: 1}
  def via_tuple(message_id), do: {:via, Horde.Registry, {__MODULE__, message_id}}

  def via_tuple(message_id, registry), do: {:via, Horde.Registry, {registry, message_id}}

  defp members do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end

end
