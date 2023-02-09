defmodule ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor do
  @moduledoc """
  Process messages received via event bus.

  The event bus client logic is implemented via the event_bus_* modules. Uppon connection
  and subscription to a queue, those clients deliver the message to
  MessageProcessor.handle_message/1 via configuration:

    config |> Map.put(
      "handle_message_fn",
      &ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor.handle_message/1
    )
  """

  alias ChannelBridgeEx.Core.CloudEvent
  alias ChannelBridgeEx.Core.CloudEvent.{RoutingError, Parser.DefaultParser}
  alias ChannelBridgeEx.Boundary.{ChannelManager, ChannelRegistry}

  require Logger

  @doc """
  Receives the raw mesages from the event bus and performs the processing for each.
  """
  def handle_message(input_json_message) do
    input_json_message
    |> convert_to_cloud_event
    |> find_channel_process
    |> deliver
  end

  defp convert_to_cloud_event(json_message) do
    start = System.monotonic_time()

    case DefaultParser.parse(json_message) do
      {:ok, data_map} ->
        metric([:adf, :cloudevent, :parsing, :stop], start, %{})
        CloudEvent.from(data_map)

      {:error, reason} ->
        metric([:adf, :cloudevent, :parsing, :exception], start, %{reason: reason})
        {:error, reason, json_message}
    end
  end

  defp find_channel_process({:ok, cloud_event}) do
    with {:ok, channel_alias} <- CloudEvent.extract_channel_alias(cloud_event) do
      case ChannelRegistry.lookup_channel_addr(channel_alias) do
        :noproc ->
          :telemetry.execute([:adf, :channel, :missing], %{time: System.monotonic_time()}, %{
            reason: :noproc
          })

          {:error, %RoutingError{message: "No process found with alias #{channel_alias}"},
           cloud_event}

        pid ->
          {:ok, pid, cloud_event}
      end
    else
      {:error, reason} ->
        :telemetry.execute([:adf, :channel, :alias_missing], %{time: System.monotonic_time()}, %{
          reason: reason
        })

        {:error, %RoutingError{message: "Unable to extract channel alias from message"},
         cloud_event}
    end
  end

  defp find_channel_process({:error, _reason, _message} = result) do
    result
  end

  defp deliver({:ok, channel_pid, cloud_event}) do
    ChannelManager.deliver_message(channel_pid, cloud_event)
  end

  defp deliver({:error, reason, data}) do
    Logger.error("Could not process message: #{inspect(data)}, reason: #{inspect(reason)}")
    # how to handle invalid msgs?
    {:error, reason, data}
  end

  defp metric(event, start_time, metadata) do
    :telemetry.execute(event, %{duration: System.monotonic_time() - start_time}, metadata)
  end
end
