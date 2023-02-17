defmodule ChannelBridgeEx.ApplicationConfig do
  @moduledoc false
  alias Vapor.Provider.File

  require Logger

  def load() do
    config_file = Application.get_env(:channel_bridge_ex, :config_file)
    Logger.info("Loading configuration from #{inspect(config_file)}")

    # Vapor
    providers = [
      %File{
        path: config_file,
        bindings: [
          bridge: "bridge",
          sender: "sender",
          aws: "aws",
          logger: "logger"
        ]
      }
    ]

    Vapor.load!(providers)
    |> load_system_env
    |> setup_aws_config

  end

  def load_system_env(config) do

    Logger.configure(level: String.to_existing_atom(get_in(config, [:logger, "level"])))

    Application.put_env(:channel_bridge_ex, :request_app_identifier, {
      String.to_atom(get_in(config, [:bridge, "request_app_identifier", "strategy"])),
      get_in(config, [:bridge, "request_app_identifier", "field"])
    })

    Application.put_env(:channel_bridge_ex, :request_user_identifier,
      get_in(config, [:bridge, "request_user_identifier"])
    )

    Application.put_env(:channel_bridge_ex, :request_channel_identifier,
      get_in(config, [:bridge, "request_channel_identifier"])
    )

    Application.put_env(:channel_bridge_ex, :cloud_event_channel_identifier,
      get_in(config, [:bridge, "cloud_event_channel_identifier"])
    )

    Application.put_env(:channel_bridge_ex, :channel_authenticator,
      String.to_existing_atom("Elixir." <> get_in(config, [:bridge, "authenticator"]))
    )

    Application.put_env(:channel_bridge_ex, :event_mutator,
      String.to_existing_atom("Elixir." <> get_in(config, [:bridge, "mutator"]))
    )

    Application.put_env(
      :channel_bridge_ex,
      :kms_key_id,
      get_in(config, [:bridge, "kms", "key-id"])
    )

    Application.put_env(
      :channel_bridge_ex,
      :channel_sender_rest_endpoint,
      get_in(config, [:sender, "rest_endpoint"])
    )

    Application.put_env(
      :channel_bridge_ex,
      :channel_management_rest_endpoint,
      get_in(config, [:channelmanagement, "rest_endpoint"])
    )

    config
  end

  def get_rabbitmq_config(config) do
    Map.new()
    |> Map.put("broker_producer_name", get_in(config, [:bridge, "event_bus", "rabbitmq", "producername"]))
    |> Map.put("broker_producer_module", get_in(config, [:bridge, "event_bus", "rabbitmq", "producer_module"]))
    |> Map.put("broker_queue", get_in(config, [:bridge, "event_bus", "rabbitmq", "queue"]))
    |> Map.put("broker_username", get_in(config, [:bridge, "event_bus", "rabbitmq", "username"]))
    |> Map.put("broker_password", get_in(config, [:bridge, "event_bus", "rabbitmq", "password"]))
    |> Map.put("broker_hostname", get_in(config, [:bridge, "event_bus", "rabbitmq", "hostname"]))
    |> Map.put("broker_virtualhost", get_in(config, [:bridge, "event_bus", "rabbitmq", "virtualhost"]))
    |> Map.put("broker_port", get_in(config, [:bridge, "event_bus", "rabbitmq", "port"]))
    |> Map.put("broker_ssl", get_in(config, [:bridge, "event_bus", "rabbitmq", "ssl"]))
    |> Map.put("broker_secret", get_in(config, [:bridge, "event_bus", "rabbitmq", "secret"]))
    |> Map.put(
      "broker_bindings",
      Enum.map(get_in(config, [:bridge, "event_bus", "rabbitmq", "bindings"]), fn e ->
        {get_in(e, ["name"]), [routing_key: List.first(get_in(e, ["routing_key"]))]}
      end)
    )
    |> Map.put(
      "broker_producer_concurrency",
      get_in(config, [:bridge, "event_bus", "rabbitmq", "producer_concurrency"])
    )
    |> Map.put(
      "broker_producer_prefetch",
      get_in(config, [:bridge, "event_bus", "rabbitmq", "producer_prefetch"])
    )
    |> Map.put(
      "broker_processor_concurrency",
      get_in(config, [:bridge, "event_bus", "rabbitmq", "processor_concurrency"])
    )
    |> Map.put(
      "broker_processor_max_demand",
      get_in(config, [:bridge, "event_bus", "rabbitmq", "processor_max_demand"])
    )
    |> Map.put(
      "handle_message_fn",
      &ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor.handle_message/1
    )
  end

  def get_sqs_config(config) do
    Map.new()
    |> Map.put("broker_producer_name", get_in(config, [:bridge, "event_bus", "sqs", "producername"]))
    |> Map.put("broker_queue", get_in(config, [:bridge, "event_bus", "sqs", "queue"]))
    |> Map.put(
      "broker_producer_concurrency",
      get_in(config, [:bridge, "event_bus", "sqs", "producer_concurrency"])
    )
    |> Map.put(
      "broker_processor_concurrency",
      get_in(config, [:bridge, "event_bus", "sqs", "processor_concurrency"])
    )
    |> Map.put(
      "broker_processor_max_demand",
      get_in(config, [:bridge, "event_bus", "sqs", "processor_max_demand"])
    )
    |> Map.put(
      "handle_message_fn",
      &ChannelBridgeEx.Entrypoint.Pubsub.MessageProcessor.handle_message/1
    )
  end

  def setup_aws_config(config) do
    setup_aws_region(config)
    |> setup_aws_creds
    |> setup_aws_config_kms
    |> setup_aws_config_secretsmanager
    |> setup_aws_config_sqs
    |> setup_aws_config_debug
  end

  defp setup_aws_region(config) do

    region = case get_in(config, [:aws, "region"]) do
      nil -> "us-east-1"
      value -> value
    end
    Application.put_env(:ex_aws, :region, region)
    Logger.info("configured aws default region: #{region}")

    config
  end

  defp setup_aws_creds(config) do

    case get_in(config, [:aws, "creds", "access_key_id"]) do
      nil ->
        setup_aws_config_creds_with_sts(config)
      _ ->
        setup_aws_config_creds_with_keys(config)
    end

    config
  end

  defp setup_aws_config_creds_with_keys(config) do
    # Credentials configuration
    fn_system_key = fn x ->
      {:system, List.last(String.split(x, ":"))}
    end

    fn_instance_role = fn _x ->
      :instance_role
    end

    akid =
      get_in(config, [:aws, "creds", "access_key_id"])
      |> Enum.map(fn k ->
        case String.contains?(k, "SYSTEM") do
          true -> fn_system_key.(k)
          false -> fn_instance_role.(k)
        end
      end)

    Application.put_env(:ex_aws, :access_key_id, akid)

    sak =
      get_in(config, [:aws, "creds", "secret_access_key"])
      |> Enum.map(fn k ->
        case String.contains?(k, "SYSTEM") do
          true -> fn_system_key.(k)
          false -> fn_instance_role.(k)
        end
      end)

    Application.put_env(:ex_aws, :secret_access_key, sak)

    Logger.info("configured aws credentials via key/secret")

    config
  end

  defp setup_aws_config_creds_with_sts(config) do

    Application.put_env(:ex_aws, :secret_access_key, [{:awscli, "profile_name", 30}])
    Application.put_env(:ex_aws, :access_key_id, [{:awscli, "profile_name", 30}])
    Application.put_env(:ex_aws, :awscli_auth_adapter, ExAws.STS.AuthCache.AssumeRoleWebIdentityAdapter)
    Logger.info("configured aws credentials via STS")

    config
  end

  defp setup_aws_config_debug(config) do
    # Debugging
    case get_in(config, [:aws, "debug_requests"]) do
      nil -> Application.put_env(:ex_aws, :debug_requests, false)
      value -> Application.put_env(:ex_aws, :debug_requests, value)
    end

    config
  end

  defp setup_aws_config_kms(config) do

    # KMS config
    case get_in(config, [:aws, "kms"]) do
      nil ->
        Logger.info("No kms config present")

      value ->
        value_w_atoms = for {key, val} <- value, into: %{}, do: {String.to_atom(key), val}
        Logger.info("kms applied config: #{inspect(value_w_atoms)}")
        Application.put_env(:ex_aws, :kms, value_w_atoms |> Map.to_list())
    end

    config
  end

  defp setup_aws_config_secretsmanager(config) do
    # secretsmanager config
    case get_in(config, [:aws, "secretsmanager"]) do
      nil ->
        Logger.info("No secretsmanager config present")

      value ->
        value_w_atoms = for {key, val} <- value, into: %{}, do: {String.to_atom(key), val}
        Logger.info("secretsmanager applied config: #{inspect(value_w_atoms)}")
        Application.put_env(:ex_aws, :secretsmanager, value_w_atoms |> Map.to_list())
    end

    config
  end

  defp setup_aws_config_sqs(config) do

    # KMS config
    case get_in(config, [:aws, "sqs"]) do
      nil ->
        Logger.info("No sqs config present")

      value ->
        value_w_atoms = for {key, val} <- value, into: %{}, do: {String.to_atom(key), val}
        Logger.info("sqs applied config: #{inspect(value_w_atoms)}")
        Application.put_env(:ex_aws, :sqs, value_w_atoms |> Map.to_list())
    end

    config
  end

end
