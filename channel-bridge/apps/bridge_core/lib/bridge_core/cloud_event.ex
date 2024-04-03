defmodule BridgeCore.CloudEvent do
  @moduledoc """
  External representation of an emited event
  """
  require Logger

  @parser BridgeCore.CloudEvent.Parser.DefaultParser

  alias BridgeCore.CloudEvent.Extractor

  @type specVersion() :: String.t()
  @type type() :: String.t()
  @type source() :: String.t()
  @type subject() :: String.t()
  @type id() :: String.t()
  @type time() :: String.t()
  @type invoker() :: String.t()
  @type dataContentType() :: String.t()
  @type data() :: iodata()

  @type t() :: %__MODULE__{
          specVersion: specVersion(),
          type: type(),
          source: source(),
          subject: subject(),
          id: id(),
          time: time(),
          invoker: invoker(),
          dataContentType: dataContentType(),
          data: data()
        }

  @derive Jason.Encoder
  defstruct specVersion: nil,
            type: nil,
            source: nil,
            subject: nil,
            id: nil,
            time: nil,
            invoker: nil,
            dataContentType: nil,
            data: nil

  @doc """
  Creates a simple event.
  """
  @spec new(specVersion(), type(), source(), subject(), id(), time(),
    invoker(), dataContentType(), iodata()) :: t()
  def new(specVersion, type, source, subject, id, time, invoker, dataContentType, data) do
    %__MODULE__{
      specVersion: specVersion,
      type: type,
      source: source,
      subject: subject,
      id: id,
      time: time,
      invoker: invoker,
      dataContentType: dataContentType,
      data: data
    }
  end

  @doc """
  Creates an Event from a JSON payload or a Map
  """
  @spec from(String.t()) :: {:ok, t} | {:error, any, any}
  def from(json) when is_binary(json) do
    with {:ok, decoded_json} <- @parser.parse(json),
          {:ok, valid_json} <- validate(decoded_json) do
      {:ok,
        %__MODULE__{
          specVersion: valid_json["specVersion"],
          type: valid_json["type"],
          source: valid_json["source"],
          subject: valid_json["subject"],
          id: valid_json["id"],
          time: valid_json["time"],
          invoker: valid_json["invoker"],
          dataContentType: valid_json["dataContentType"],
          data: valid_json["data"]
        }}
    else
      {:error, reason} ->
        {:error, reason, json}
    end
  end

  @spec from(map()) :: {:ok, t} | {:error, any, any}
  def from(data) when is_map(data) do
    {:ok,
      %__MODULE__{
        specVersion: get_in(data, ["specVersion"]),
        type: get_in(data, ["type"]),
        source: get_in(data, ["source"]),
        subject: get_in(data, ["subject"]),
        id: get_in(data, ["id"]),
        time: get_in(data, ["time"]),
        invoker: get_in(data, ["invoker"]),
        dataContentType: get_in(data, ["dataContentType"]),
        data: get_in(data, ["data"])
      }}
  end

  @doc """
  Validates an Event
  """
  @spec validate(map()) :: {:ok, t()} | {:error, any, any}
  def validate(data) when is_map(data) do
    @parser.validate(data)
  end

  # defdelegate is_async_deliverable(cloud_event), to: Extractor

  defdelegate extract(cloud_event, path), to: Extractor

  defdelegate extract_channel_alias(cloud_event), to: Extractor

  @spec mutate(t(), atom()) :: {:ok, t()} | {:error, any}
  def mutate(cloud_event, mutator_setup) do

    mutator = mutator_setup["mutator_module"]
    mutator_config = mutator_setup["config"]

    with true <- mutator.applies?(cloud_event, mutator_config) do
      Logger.debug("Applying mutator #{inspect(mutator)} to cloud event...")

      cloud_event
      |> mutator.mutate(mutator_config)
      |> (fn result ->
        case result do
          {:ok, _mutated} ->
            Logger.debug("Cloud event mutated.")
            result

          {:noop, ce} ->
            Logger.debug("Cloud event not mutated!")
            {:ok, ce}

          {:error, reason} = err ->
            Logger.error("Message mutation error. #{inspect(reason)}")
            err
        end
          end).()
    else
      false ->
        Logger.debug("Mutator not applied to cloud event due to 'Mutator.applies?/2' returned = false")
        {:ok, cloud_event}
      {:error, reason} = err ->
        Logger.error("Message mutation decision logic error. #{inspect(reason)}")
        err
    end
  end
end
