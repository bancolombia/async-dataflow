defmodule AdfSenderConnector do
  @moduledoc """
  Client for ADF Channel Sender
  """

  use DynamicSupervisor
  require Logger

  alias AdfSenderConnector.{Credentials, Router, Message}

  @typedoc """
  Channel sender base URL
  """
  @type sender_url :: String.t()

  @typedoc """
  Application reference
  """
  @type application_ref :: String.t()

  @typedoc """
  User reference
  """
  @type user_ref :: String.t()

  @typedoc """
  Channel reference
  """
  @type channel_ref :: String.t()

  @typedoc """
  Event name
  """
  @type event_name :: String.t()

  @typedoc """
  Event payload as a Message struct
  """
  @type message :: %Message{}


  @typedoc """
  Event payload as a Map
  """
  @type message_data :: map()

  @default_local "http://localhost:8081"


  @doc """
  starts the process
  """
  # @spec start_link() :: {atom, pid}
  def start_link(init_args, _opts \\ []) do
    HTTPoison.start
    DynamicSupervisor.start_link(__MODULE__, [init_args], name: __MODULE__)
  end

  def start_link() do
    HTTPoison.start
    Logger.warning("No sender endpoint provided. Using default endpoint https://localhost:8081")
    DynamicSupervisor.start_link(__MODULE__, [sender_url: @default_local], name: __MODULE__)
  end

  @spec init(any) ::
          {:ok,
           %{
             extra_arguments: list,
             intensity: non_neg_integer,
             max_children: :infinity | non_neg_integer,
             period: pos_integer,
             strategy: :one_for_one
           }}
  @doc false
  def init(options \\ []) do
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: options)
  end

  def spec(args \\ []) do
    %{
      id: AdfSenderConnector,
      start: {AdfSenderConnector, :start_link, args}
    }
  end

  def registry_spec do
    %{
      id: Registry.ADFSenderConnector,
      start: {Registry, :start_link, [[keys: :unique, name: Registry.ADFSenderConnector]]}
    }
  end

  @spec channel_registration(application_ref(), user_ref(), list()) :: {:ok, map()} | {:error, any()}
  @doc """
  Request a channel registration
  """
  def channel_registration(application_ref, user_ref, options \\ []) do
    case find_creds_process(application_ref <> "." <> user_ref) do
      :noproc ->
        {:ok, pid} = start_creds_proc(application_ref, user_ref, options)
        Credentials.exchange_credentials(pid)
      pid ->
        Credentials.exchange_credentials(pid)
    end
  end

  defp start_creds_proc(application_ref, user_ref, options) do
    DynamicSupervisor.start_child(__MODULE__,
      Credentials.child_spec([
        app_ref: application_ref,
        user_ref: user_ref,
        name: application_ref <> "." <> user_ref] ++ options))
  end

  defp find_creds_process(name) do
    case Registry.lookup(Registry.ADFSenderConnector, name) do
      [{pid, _}] ->
        pid
      [] ->
        :noproc
    end
  end

  @doc """
  Starts a process to deliver messages.
  """
  @spec start_router_process(channel_ref(), list()) :: :ok | {:error, any()}
  def start_router_process(channel_ref, options \\ []) do
    new_options = Keyword.delete(options, :name)
    Logger.debug("Starting routing process: #{inspect(channel_ref)}")
    DynamicSupervisor.start_child(__MODULE__, Router.child_spec([name: channel_ref] ++ new_options))
  end

  @doc """
  Stops a routing process.
  """
  @spec stop_router_process(channel_ref()) :: :ok | {:error, any()}
  def stop_router_process(channel_ref) do
    Logger.debug("Stopping routing process: #{inspect(channel_ref)}")
    DynamicSupervisor.stop(__MODULE__, channel_ref)
  end

  @spec route_message(channel_ref(), event_name(), message() | message_data()) :: {:ok, map()} | {:error, any()}
  @doc """
  Request a message delivery by creating a protocol message with the data provided
  """
  def route_message(channel_ref, event_name, message) do
    case Registry.lookup(Registry.ADFSenderConnector, channel_ref) do
      [{pid, _}] ->
        if %Message{} == message do
          Router.route_message(pid, message)
        else
          Router.route_message(pid, event_name, message)
        end
      [] ->
        Logger.warning(":unknown_channel_reference #{inspect(channel_ref)}")
        {:error, :unknown_channel_reference}
    end
  end

end
