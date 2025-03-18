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

    Logger.configure(level: String.to_existing_atom(
      Map.get(fetch(config, :logger), "level", "info")
    ))

    Application.put_env(:channel_sender_ex, :secret_base,
      {
        Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "base",
          "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc"),
        Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "salt", "10293846571")
      }
    )

    Application.put_env(:channel_sender_ex, :no_start,
      Map.get(fetch(config, :channel_sender_ex), "no_start", false)
    )

    Application.put_env(:channel_sender_ex, :max_age,
      Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "max_age", 900)
    )

    Application.put_env(:channel_sender_ex, :rest_port,
      Map.get(fetch(config, :channel_sender_ex), "rest_port", 8081)
    )

    Application.put_env(:channel_sender_ex, :initial_redelivery_time,
      Map.get(fetch(config, :channel_sender_ex), "initial_redelivery_time", 900)
    )

    Application.put_env(:channel_sender_ex, :max_unacknowledged_retries,
      Map.get(fetch(config, :channel_sender_ex), "max_unacknowledged_retries", 20)
    )

    Application.put_env(:channel_sender_ex, :api_gateway_connection,
      Map.get(fetch(config, :channel_sender_ex), "api_gateway_connection", "")
    )

    Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "base",
          "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc")

    apig_config = parse_api_gateway(config)
    endpoint = resolve_api_gateway_endpoint(
      apig_config[:endpoint],
      apig_config[:domain],
      apig_config[:api],
      apig_config[:region],
      apig_config[:stage]
    )
    Application.put_env(:channel_sender_ex, :api_gateway_connection, endpoint)

    Application.put_env(:channel_sender_ex, :api_id, apig_config[:api])
    Application.put_env(:channel_sender_ex, :api_region, apig_config[:region])
    Application.put_env(:channel_sender_ex, :api_stage, apig_config[:stage])

    Application.put_env(:channel_sender_ex, :topology, parse_libcluster_topology(config))

    persistence_cfg = parse_persistence(config)
    Application.put_env(:channel_sender_ex, :persistence, persistence_cfg)
    Application.put_env(:channel_sender_ex, :persistence_ttl, persistence_cfg[:ttl] || 900)

    if config == %{} do
      Logger.warning("No valid configuration found!!!, Loading pre-defined default values : #{inspect(Application.get_all_env(:channel_sender_ex))}")
    else
      Logger.info("Succesfully loaded configuration: #{inspect(inspect(Application.get_all_env(:channel_sender_ex)))}")
    end

    config
  end

  defp parse_api_gateway(config) do
    apigateway = fetch(config, :channel_sender_ex, "api_gateway")
    [
      api: Map.get(apigateway, "api", "000000"),
      region: Map.get(apigateway, "region", "us-east-1"),
      stage: Map.get(apigateway, "stage", "dev"),
      domain: Map.get(apigateway, "domain", nil),
      endpoint: Map.get(apigateway, "endpoint", nil)
    ]
  end

  defp resolve_api_gateway_endpoint(endpoint, _domain, _api, _region, _stage) when is_binary(endpoint) do
     endpoint
  end
  defp resolve_api_gateway_endpoint(_endpoint, domain, _api, _region, stage) when is_binary(domain) do
    "https://#{domain}/#{stage}/@connections/"
  end
  defp resolve_api_gateway_endpoint(_endpoint, _domain, api, region, stage) do
    "https://#{api}.execute-api.#{region}.amazonaws.com/#{stage}/@connections/"
  end

  defp parse_persistence(config) do
    persistence = fetch(config, :channel_sender_ex, "persistence")
    [
      enabled: Map.get(persistence, "enabled", false),
      type: process_param(Map.get(persistence, "type", ":none")),
      config: parse_config_key(Map.get(persistence, "config", %{}))
    ]
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
        Enum.map(cfg, fn({key, value}) ->
          {String.to_atom(key), process_param(value)}
        end)
    end
  end

  defp process_param(_param = "nil"), do: nil
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
