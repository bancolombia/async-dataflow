defmodule BridgeRabbitmq.MessageProcessor do
  @moduledoc """
  Process messages received via event bus.

  """

  alias BridgeCore.CloudEvent
  alias BridgeCore.CloudEvent.Parser.DefaultParser
  alias BridgeCore.CloudEvent.RoutingError

  require Logger

  @doc """
  Receives the raw mesages from the event bus and performs the processing for each.
  """
  def handle_message(input_json_message) do

    # ----------------------------------------------------------------
    # The delivery task is done under a supervisor in order to provide
    # retry functionality
    Task.Supervisor.start_child(
      BridgeRabbitmq.TaskSupervisor,
      fn ->

        send_result = input_json_message
        |> convert_to_cloud_event
        |> find_process_and_deliver

        case send_result do
          :ok ->
            Logger.debug("Success: Message routing requested.")
            :ok

          {:error, err, _cloud_event} ->
            # Logger.error("Error: Message routing failed!, reason: #{inspect(err)}")
            raise RoutingError, message: err
            # :error
        end
      end,
      restart: :transient
    )
    # End of delivery task---------------------------------------------

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

  defp find_process_and_deliver({:ok, cloud_event}) do
    with {:ok, channel_alias} <- CloudEvent.extract_channel_alias(cloud_event),
          :ok <- BridgeCore.route_message(channel_alias, cloud_event) do
      :ok
    else
      {:error, :noproc} ->
        {:error, "Unable to find a routing process tied to channel alias", cloud_event}

      {:error, reason} ->
        :telemetry.execute([:adf, :channel, :alias_missing], %{time: System.monotonic_time()}, %{
          reason: reason
        })

        {:error, "Unable to extract channel alias from message", cloud_event}
    end
  end

  defp find_process_and_deliver({:error, _reason, _message} = result) do
    result
  end

  defp metric(event, start_time, metadata) do
    :telemetry.execute(event, %{duration: System.monotonic_time() - start_time}, metadata)
  end
end
