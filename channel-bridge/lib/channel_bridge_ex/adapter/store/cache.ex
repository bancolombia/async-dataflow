defmodule ChannelBridgeEx.Adapter.Store.Cache do
  @behaviour ChannelBridgeEx.Core.CachingProvider

  @moduledoc """
  The in-memory cache backed by an ETS table.
  """

  @type ttl :: integer
  @type cached_at :: integer

  alias ChannelBridgeEx.Utils.Timestamp

  use GenServer

  @table_name :channel_bridge_ex_cache
  @table_options [
    :set,
    :protected,
    :named_table,
    {:read_concurrency, true}
  ]

  @doc false
  def worker_spec(args \\ nil) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :permanent,
      type: :worker
    }
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # We lookup without going through the GenServer
  # for concurrency and perfomance.
  #
  @doc false
  @impl true
  def get(cache_key) do
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, {value, timestamp, ttl}}] ->
        validate(cache_key, value, timestamp, ttl)

      _ ->
        {:miss, :not_found, nil}
    end
  end

  defp validate(_name, value, timestamp, ttl) do
    if expired?(timestamp, ttl) do
      {:miss, :expired, value}
    else
      {:ok, value}
    end
  end

  defp validate(_name, _value, _timestamp, _ttl) do
    {:miss, :invalid, nil}
  end

  defp expired?(timestamp, ttl) do
    Timestamp.has_elapsed(timestamp + ttl)
  end

  # We want to always write serially through the
  # GenServer to avoid race conditions.
  #
  @doc false
  @impl true
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  @doc """
  Clears the cache. It will be rebuilt gradually as the public interface of the
  package is queried.
  """
  @spec flush() :: true
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Returns the contents of the cache ETS table, for inspection.
  """
  @spec dump() :: [{atom, {any(), cached_at, ttl}}]
  def dump do
    :ets.tab2list(@table_name)
  end

  # ------------------------------------------------------------
  # GenServer callbacks

  @impl true
  def init(opts) do
    tab_name = @table_name
    ^tab_name = :ets.new(@table_name, @table_options)
    {:ok, %{tab_name: tab_name, ttl: List.first(opts)}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, %{ttl: ttl} = state) do
    # writing to an ETS table will either return true or raise
    :ets.insert(@table_name, {key, {value, Timestamp.now(), ttl}})
    {:reply, {:ok, value}, state}
  end

  @doc false
  def handle_call(:flush, _from, state) do
    {:reply, :ets.delete_all_objects(@table_name), state}
  end
end
