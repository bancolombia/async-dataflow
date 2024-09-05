defmodule BridgeCore.CloudEvent.Parser.DefaultParser do
  @moduledoc """
  Default Parser and schema validator for CloudEvents
  """
  @behaviour BridgeCore.CloudEvent.Parser

  require Logger

  alias BridgeCore.CloudEvent.Parser
  alias Jason
  alias JsonXema

  @type t :: CloudEvent

  # @impl true
  @spec parse(Parser.encoded_json()) :: {:ok, Parser.json()} | {:error, any()}
  def parse(encoded_json) do
    decoded =
      Jason.decode!(encoded_json)
      |> trim_cloud_event

    {:ok, decoded}
  rescue
    x in Jason.DecodeError ->
      Logger.error("Received message is NOT a valid JSON: #{inspect(encoded_json)}")
      {:error, x}
  end

  @impl true
  @spec validate(Parser.json()) :: {:ok, Parser.json()} | {:error, struct()}
  def validate(json) do
    case JsonXema.validate(get_schema(), json) do
      :ok ->
        {:ok, json}

      {:error, _reasons} = err ->
        err
    end
  end

  defp trim_cloud_event(decoded_json) do
    case Map.has_key?(decoded_json, "eventId") do
      true ->
        Map.get(decoded_json, "data")

      false ->
        decoded_json
    end
  end

  defp get_schema do
    :persistent_term.get({DefaultParser, "schema"})
  rescue
    ArgumentError ->
      new_schema = create_schema()
      :persistent_term.put({DefaultParser, "schema"}, new_schema)
      new_schema
  end

  defp create_schema do
    %{
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "properties" => %{
        "data" => %{
          "type" => "object"
        },
        "dataContentType" => %{"type" => "string"},
        "id" => %{"type" => "string"},
        "source" => %{"type" => "string"},
        "subject" => %{"type" => "string"},
        "specversion" => %{"type" => "string"},
        "time" => %{"type" => "string"},
        "type" => %{"type" => "string"}
      },
      "required" => [
        "data",
        "dataContentType",
        "id",
        "source",
        "subject",
        "specVersion",
        "time",
        "type"
      ],
      "type" => "object"
    }
    |> JsonXema.new()
  end
end
