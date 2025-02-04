defmodule ChannelSenderEx.Core.ChannelRegistry do
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
    Logger.debug("Channel registry init #{inspect(result)}")
    result
  end

  @spec lookup_channel_addr(channel_ref()) :: :noproc | channel_addr()
  @compile {:inline, lookup_channel_addr: 1}
  def lookup_channel_addr(channel_ref) do
    case Horde.Registry.lookup(via_tuple(channel_ref)) do
      [{pid, _}] -> pid
      [] -> :noproc
    end
  end

  @spec query_by_app(String.t()) :: Enumerable.t()
  def query_by_app(app) do
    # select pattern is: $1 = channel_ref, $2 = pid, $3 = app_ref, $4 = user_ref
    # guard condition is to match $3 with app ref
    # return $2 which is the pid of the process
    Stream.map(Horde.Registry.select(__MODULE__, [
      {{:"$1", :"$2", {:"$3", :"$4"}}, [{:==, :"$3", app}], [:"$2"]}
      ]), fn pid -> pid end)
  end

  @spec query_by_user(String.t()) :: Enumerable.t()
  def query_by_user(user) do
    # select pattern is: $1 = channel_ref, $2 = pid, $3 = app_ref, $4 = user_ref
    # guard condition is to match $4 with user ref
    # return $2 which is the pid of the process
    Stream.map(Horde.Registry.select(__MODULE__, [
      {{:"$1", :"$2", {:"$3", :"$4"}}, [{:==, :"$4", user}], [:"$2"]}
      ]), fn pid -> pid end)
  end

  @compile {:inline, via_tuple: 1}
  def via_tuple(channel_ref), do: {:via, Horde.Registry, {__MODULE__, channel_ref}}

  def via_tuple(channel_ref, registry), do: {:via, Horde.Registry, {registry, channel_ref}}

  defp members do
    Enum.map([Node.self() | Node.list()], &{__MODULE__, &1})
  end

end
