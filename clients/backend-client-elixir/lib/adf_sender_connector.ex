defmodule AdfSenderConnector do
  @moduledoc """
  Client for ADF Channel Sender
  """

  use Supervisor
  require Logger

  alias AdfSenderConnector.{Channel, Router}

  @options_definition [
    name: [
      type: :atom,
      required: true
    ],
    sender_url: [
      type: :string,
      required: true
    ]
  ]

  @doc """
  starts the process
  """
  @spec start_link(Keyword.t) :: {atom, pid}
  def start_link(options) when is_list(options) do
    Supervisor.start_link(__MODULE__, options, [name: Keyword.fetch!(options, :name)])
  end

  @doc false
  # Basic initialization
  @spec init(options :: Keyword.t()) :: Supervisor.on_start
  def init(options \\ []) do
    case NimbleOptions.validate(options, @options_definition) do
      {:ok, _} ->
        options
        |> services_spec
        |> Supervisor.init(strategy: :one_for_one)
      {:error, reason} ->
        Logger.error("Invalid configuration provided, #{inspect(reason)}")
        raise reason
    end
  end

  @doc """
  Request a channel registration
  """
  def create_channel(server, application_ref, user_ref) do
    {:ok, pid} = find_by_name(AdfSenderConnector.Channel, server)
    Channel.create_channel(pid, application_ref, user_ref)
  end

  @doc """
  Request a message delivery by creating a protocol message with the data provided
  """
  def deliver_message(server, channel_ref, event_name, message) do
    {:ok, pid} = find_by_name(AdfSenderConnector.Router, server)
    Router.deliver_message(pid, channel_ref, event_name, message)
  end

  @doc """
  Request the delivery of a protocol message
  """
  def deliver_message(server, protocol_message) do
    {:ok, pid} = find_by_name(AdfSenderConnector.Router, server)
    Router.deliver_message(pid, protocol_message)
  end

  defp services_spec(options) do
    [
      {Registry, keys: :unique, name: Registry.ADFSenderConnector},
      Channel.child_spec(options),
      Router.child_spec(options)
    ]
  end

  defp find_by_name(module, name) do
    case Registry.lookup(Registry.ADFSenderConnector, Atom.to_string(module) <> "." <> Atom.to_string(name)) do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        :error
    end
  end

end
