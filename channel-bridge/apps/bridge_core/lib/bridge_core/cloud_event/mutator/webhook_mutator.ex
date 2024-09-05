defmodule BridgeCore.CloudEvent.Mutator.WebhookMutator do
  @moduledoc """
  A module that invokes a rest endpoint and pass the cloudevent, to be mutated, as a parameter.
  The rest endpoint is expected to return a mutated cloudevent.

  an example of the configuration for this mutator is:

  bridge:
    cloud_event_mutator:
      mutator_module: Elixir.BridgeCore.CloudEvent.Mutator.WebhookMutator
      config:
        webhook_url: "http://localhost:8081"
        webhook_method: "POST"
        webhook_headers:
          - "Content-Type: application/json"
        applies_when:
          - key: "$.data"
            comparator: "eq"
            value: "demo1"
          - key: "$.subject"
            comparator: "contains"
            value: "foo"
            operator: "and"
  """
  @behaviour BridgeCore.CloudEvent.Mutator

  require Logger
  alias BridgeCore.CloudEvent
  alias BridgeCore.Utils.JsonSearch

  @type t() :: CloudEvent.t()

  @webhook_content_type ['application/json']
  @webhook_options [{:timeout, 3_000}, {:connect_timeout, 3_000}]

  @doc false
  @impl true
  def applies?(cloud_event, config) do
    Stream.map(config["applies_when"], fn rule ->
      key = rule["key"]
      comparator = rule["comparator"]
      value = rule["value"]
      bool_op = rule["operator"] || "or"
      part = get_part(cloud_event, key, comparator)
      cond do
        comparator?(comparator) ->
          {bool_op, compare(comparator, value, part)}
        contains?(comparator) ->
            {bool_op, contained(comparator, value, part)}
        regex?(comparator) ->
          {bool_op, Regex.match?(~r/#{value}/, part)}
      end
    end)
    |> Enum.to_list()
    |> Enum.reduce(false, fn {op, value}, acc ->
      case op do
        "and" -> acc && value
        "or" -> acc || value
      end
    end)
  end

  defp get_part(cloud_event, key, _operator) do
    JsonSearch.prepare(cloud_event)
    |> JsonSearch.extract(key)
  end

  defp comparator?(operator) do
    operator in ["eq", "ne", "gt", "lt", "ge", "le"]
  end

  defp contains?(operator) do
    operator in ["contains", "not_contains"]
  end

  defp regex?(operator) do
    operator in ["regex"]
  end

  defp compare(operator, value, part) do
    case operator do
      "eq" -> part == value
      "ne" -> part != value
      "gt" -> part > value
      "lt" -> part < value
      "ge" -> part >= value
      "le" -> part <= value
      _ -> false
    end
  end

  defp contained(operator, value, part) do
    case operator do
      "contains" -> String.contains?(part, value)
      "not_contains" -> !String.contains?(part, value)
      _ -> false
    end
  end

  @doc false
  @impl true
  def mutate(cloud_event, config) do
    encode_cloud_event(cloud_event)
    |> invoke_webhook(config)
    |> process_response(cloud_event)
  end

  defp encode_cloud_event(cloud_event) do
    case Jason.encode(cloud_event) do
      {:ok, _encoded_cloud_event} = res ->
        res
      {:error, reason} ->
        Logger.error("Error encoding cloud event prior to invoking webhook: #{inspect(reason)}")
        {:noop, reason}
    end
  end

  defp invoke_webhook({:ok, encoded_cloud_event}, config) do
    :httpc.request(:post,
      {config["webhook_url"], parse_headers(config), @webhook_content_type, encoded_cloud_event},
      @webhook_options, [])
  end

  defp invoke_webhook({:noop, reason}, _) do
    {:noop, reason}
  end

  defp process_response({:ok, {{_, status, _}, _, response_body}}, cloud_event) do
    if status < 200 or status >= 300 do
      Logger.error("Webhook result unsuccessful: #{inspect(status)}, body: #{inspect(response_body)}")
      {:noop, cloud_event}
    else
      case CloudEvent.from(to_string(response_body)) do
        {:error, reason, _} ->
          Logger.error("Error parsing webhook response: #{inspect(reason)}")
          {:noop, cloud_event}
        {:ok, new_ce} ->
          {:ok, %{cloud_event | data: new_ce.data}}
      end
    end
  end

  defp process_response({:error, reason}, cloud_event) do
    Logger.error("Error invoking webhook: #{inspect(reason)}")
    {:noop, cloud_event}
  end

  defp process_response({:noop, _reason}, cloud_event) do
    {:noop, cloud_event}
  end

  defp parse_headers(config) do
    if config["webhook_headers"] == nil do
      [{'accept', 'application/json'}]
    else
      Stream.map(config["webhook_headers"], fn str_header ->
        String.split(str_header, ":")
      end)
      |> Stream.map(fn [key, value] -> {to_charlist(key), to_charlist(String.trim(value))} end)
      |> Enum.to_list()
    end
  end

end
