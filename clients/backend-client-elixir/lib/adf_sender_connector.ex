defmodule AdfSenderConnector do
  @moduledoc """
  Client for ADF Channel Sender
  """

  use DynamicSupervisor
  require Logger

  alias AdfSenderConnector.{Channel, Router, Message}

  @doc """
  starts the process
  """
  # @spec start_link() :: {atom, pid}
  def start_link() do
    HTTPoison.start
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
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
  # Basic initialization
  # @spec init(options :: Keyword.t()) :: {:ok, any()}
  def init(_options \\ []) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # def start_registry do
  #   DynamicSupervisor.start_child(__MODULE__, registry_spec())
  # end
  def spec do
    %{
      id: AdfSenderConnector,
      start: {AdfSenderConnector, :start_link, []}
    }
  end

  def registry_spec do
    %{
      id: Registry.ADFSenderConnector,
      start: {Registry, :start_link, [[keys: :unique, name: Registry.ADFSenderConnector]]}
    }
  end

  @spec channel_registration(any, any, any) :: {:ok, any()} | {:error, any()}
  @doc """
  Request a channel registration
  """
  def channel_registration(application_ref, user_ref, options) do
    new_ch = DynamicSupervisor.start_child(__MODULE__,
      Channel.child_spec([
        app_ref: application_ref,
        user_ref: user_ref,
        name: application_ref <> "." <> user_ref] ++ options))

    case new_ch do
      {:ok, pid} ->
        Channel.exchange_credentials(pid)
      _ ->
        new_ch
    end
  end

  @spec route_message(pid(), any, any) :: :ok | {:error, any()}
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
        {:error, :unknown_channel_reference}
    end
  end

end
