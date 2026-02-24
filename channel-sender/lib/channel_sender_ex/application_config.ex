defmodule ChannelSenderEx.ApplicationConfig do
  @moduledoc false

  alias Vapor.Provider.File

  require Logger

  def load do
    config_file = Application.get_env(:channel_sender_ex, :config_file)
    Logger.info("Loading configuration from #{inspect(config_file)}")

    # Vapor
    providers = [
      %File{
        path: config_file,
        bindings: [
          channel_sender_ex: "channel_sender_ex",
          logger: "logger"
        ]
      }
    ]

    try do
      case Vapor.load(providers) do
        {:error, err} ->
          Logger.error("Error loading configuration, #{inspect(err)}")
          setup_config(%{})

        {:ok, config} ->
          setup_config(config)
      end
    rescue
      e in Vapor.FileNotFoundError ->
        Logger.error("Error loading configuration, #{inspect(e)}")
        setup_config(%{})
    end
  end

  def setup_config(config) do
    Logger.configure(
      level: String.to_existing_atom(Map.get(fetch(config, :logger), "level", "info"))
    )

    Application.put_env(
      :channel_sender_ex,
      :no_start,
      Map.get(fetch(config, :channel_sender_ex), "no_start", false)
    )

    Application.put_env(
      :channel_sender_ex,
      :channel_shutdown_tolerance,
      Map.get(fetch(config, :channel_sender_ex), "channel_shutdown_tolerance", 10_000)
    )

    Application.put_env(
      :channel_sender_ex,
      :min_disconnection_tolerance,
      Map.get(fetch(config, :channel_sender_ex), "min_disconnection_tolerance", 50)
    )

    Application.put_env(
      :channel_sender_ex,
      :on_connected_channel_reply_timeout,
      Map.get(fetch(config, :channel_sender_ex), "on_connected_channel_reply_timeout", 2000)
    )

    Application.put_env(
      :channel_sender_ex,
      :accept_channel_reply_timeout,
      Map.get(fetch(config, :channel_sender_ex), "accept_channel_reply_timeout", 1000)
    )

    Application.put_env(:channel_sender_ex, :secret_base, {
      Map.get(
        fetch(config, :channel_sender_ex, "secret_generator"),
        "base",
        "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc"
      ),
      Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "salt", "10293846571")
    })

    Application.put_env(
      :channel_sender_ex,
      :max_age,
      Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "max_age", 900)
    )

    Application.put_env(
      :channel_sender_ex,
      :socket_port,
      Map.get(fetch(config, :channel_sender_ex), "socket_port", 8082)
    )

    Application.put_env(
      :channel_sender_ex,
      :rest_port,
      Map.get(fetch(config, :channel_sender_ex), "rest_port", 8081)
    )

    Application.put_env(
      :channel_sender_ex,
      :initial_redelivery_time,
      Map.get(fetch(config, :channel_sender_ex), "initial_redelivery_time", 900)
    )

    Application.put_env(
      :channel_sender_ex,
      :socket_idle_timeout,
      Map.get(fetch(config, :channel_sender_ex), "socket_idle_timeout", 30_000)
    )

    Application.put_env(
      :channel_sender_ex,
      :max_unacknowledged_retries,
      Map.get(fetch(config, :channel_sender_ex), "max_unacknowledged_retries", 20)
    )

    Application.put_env(
      :channel_sender_ex,
      :max_unacknowledged_queue,
      Map.get(fetch(config, :channel_sender_ex), "max_unacknowledged_queue", 100)
    )

    Application.put_env(
      :channel_sender_ex,
      :max_pending_queue,
      Map.get(fetch(config, :channel_sender_ex), "max_pending_queue", 100)
    )

    channel_wait_times =
      Map.get(fetch(config, :channel_sender_ex), "channel_shutdown_socket_disconnect", %{
        "on_clean_close" => 30,
        "on_disconnection" => 300
      })

    Application.put_env(
      :channel_sender_ex,
      :channel_shutdown_on_clean_close,
      Map.get(channel_wait_times, "on_clean_close", 30)
    )

    Application.put_env(
      :channel_sender_ex,
      :channel_shutdown_on_disconnection,
      Map.get(channel_wait_times, "on_disconnection", 300)
    )

    Application.put_env(
      :channel_sender_ex,
      :prometheus_port,
      Map.get(fetch(config, :channel_sender_ex, "metrics"), "prometheus_port", 9568)
    )

    Application.put_env(:channel_sender_ex, :topology, parse_libcluster_topology(config))

    Application.put_env(
      :channel_sender_ex,
      :traces_enable,
      get_in(config, [:channel_sender_ex, "opentelemetry", "traces_enable"])
    )

    Application.put_env(
      :channel_sender_ex,
      :traces_endpoint,
      get_in(config, [:channel_sender_ex, "opentelemetry", "traces_endpoint"])
    )

    Application.put_env(
      :channel_sender_ex,
      :traces_ignore_routes,
      get_in(config, [:channel_sender_ex, "opentelemetry", "traces_ignore_routes"])
    )

    Application.put_env(
      :channel_sender_ex,
      :metrics_enabled,
      get_in(config, [:channel_sender_ex, "metrics", "enabled"])
    )

    Application.put_env(
      :channel_sender_ex,
      :interval_minutes_count_active_channel,
      get_in(config, [:channel_sender_ex, "metrics", "active_interval_minutes_count"])
    )

    if config == %{} do
      Logger.warning(
        "No valid configuration found!!!, Loading pre-defined default values : #{inspect(Application.get_all_env(:channel_sender_ex))}"
      )
    else
      Logger.info(
        "Succesfully loaded configuration: #{inspect(inspect(Application.get_all_env(:channel_sender_ex)))}"
      )
    end

    Application.put_env(
      :channel_sender_ex,
      :cowboy_protocol_options,
      parse_cowboy_protocol_opts(
        get_in(config, [:channel_sender_ex, "cowboy", "protocol_options"])
      )
    )

    Application.put_env(
      :channel_sender_ex,
      :cowboy_transport_options,
      parse_cowboy_transport_opts(
        get_in(config, [:channel_sender_ex, "cowboy", "transport_options"])
      )
    )

    config
  end

  defp parse_cowboy_protocol_opts(opts) do
    case opts do
      nil ->
        [
          active_n: 1_000,
          max_keepalive: 5_000,
          request_timeout: 10_000
        ]

      _ ->
        parse_config_key(opts)
    end
  end

  defp parse_cowboy_transport_opts(opts) do
    case opts do
      nil ->
        [
          num_acceptors: 200,
          max_connections: 16_384
        ]

      _ ->
        parse_config_key(opts)
    end
  end

  defp parse_libcluster_topology(config) do
    topology = get_in(config, [:channel_sender_ex, "topology"])

    case topology do
      nil ->
        Logger.warning("No libcluster topology defined!!! -> Using Default [Gossip]")
        [strategy: Cluster.Strategy.Gossip]

      _ ->
        [
          strategy: String.to_existing_atom(topology["strategy"]),
          config: parse_config_key(topology["config"])
        ]
    end
  end

  defp parse_config_key(cfg) do
    case cfg do
      nil ->
        []

      _ ->
        Enum.map(cfg, fn {key, value} ->
          {String.to_atom(key), process_param(value)}
        end)
    end
  end

  defp process_param(param) when is_binary(param) do
    case String.starts_with?(param, ":") do
      true ->
        String.to_atom(String.replace_leading(param, ":", ""))

      false ->
        param
    end
  end

  defp process_param(param) do
    param
  end

  defp fetch(config, base) do
    case get_in(config, [base]) do
      nil ->
        %{}

      data ->
        data
    end
  end

  defp fetch(config, base, key) do
    case get_in(config, [base, key]) do
      nil ->
        %{}

      data ->
        data
    end
  end
end
