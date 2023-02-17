defmodule ChannelBridgeEx.Core.CloudEvent.Parser.DefaultParser do
  @moduledoc """
  Default Parser and schema validator for CloudEvents
  """
  @behaviour ChannelBridgeEx.Core.CloudEvent.Parser

  alias ChannelBridgeEx.Core.CloudEvent.Parser

  alias Jason
  alias JsonXema

  @type t :: CloudEvent

  # @impl true
  @spec parse(Parser.encoded_json()) :: {:ok, Parser.json()} | {:error, any()}
  def parse(encoded_json) do
    try do
      decoded =
        Jason.decode!(encoded_json)
        |> trim_cloud_event

      {:ok, decoded}
    rescue
      x in Jason.DecodeError -> {:error, x}
    end
  end

  @impl true
  @spec validate(Parser.json()) :: {:ok, Parser.json()} | {:error, any()}
  def validate(json) do
    case JsonXema.validate(get_schema(), json) do
      :ok ->
        {:ok, json}

      {:error, reasons} ->
        {:error, reasons}
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

  defp get_schema() do
    try do
      :persistent_term.get({DefaultParser, "schema"})
    rescue
      ArgumentError ->
        new_schema = create_schema()
        :persistent_term.put({DefaultParser, "schema"}, new_schema)
        new_schema
    end
  end

  defp create_schema() do
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
