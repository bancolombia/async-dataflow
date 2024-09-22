defmodule StreamsRabbitmq.Application do
  @moduledoc """
  Main application entry point.
  """
  use Application
  require Logger

  @doc false
  @impl Application
  def start(_type, _args) do

    children = case (Application.get_env(:streams_core, :env)) do
      e when e in [:test, :bench] ->
        [
          {Task.Supervisor, name: StreamsRabbitmq.TaskSupervisor, options: [max_restarts: 2]}
        ]
      _ ->
        [
          build_child_spec(Application.get_env(:channel_streams, :config)),
          {Task.Supervisor, name: StreamsRabbitmq.TaskSupervisor, options: [max_restarts: 2]}
        ]
    end

    Logger.info("StreamsRabbitmq.Application starting...")

    opts = [strategy: :one_for_one, name: StreamsRabbitmq.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def build_child_spec(config) do
    rabbit_config = get_in(config, [:streams, "event_bus", "rabbitmq"])
    new_config = Map.put_new(rabbit_config, "broker_url", parse_connection_details(rabbit_config))
    {StreamsRabbitmq.Subscriber, [new_config]}
  end

  defp parse_connection_details(config) do
    # If a secret is specified, obtain data from Aws Secretsmanager,
    # otherwise build connection string from explicit keys in file
    case get_in(config, ["secret"]) do
      nil ->
        build_uri(config)
      secret_name ->
        load_credentials_secret(secret_name)
    end
  end

  defp load_credentials_secret(secret_name) do
    Logger.info("Fetching RabbitMQ credentials from Secret...")
    case StreamsSecretManager.get_secret(secret_name, [output: "json"]) do
      {:ok, secret_json} ->
        print_secret(secret_json)
        build_uri(secret_json)
      {:error, reason} ->
        raise reason
    end
  end

  defp build_uri(data) do
    username = get_in(data, ["username"])
    password = case get_in(data, ["password"]) do
      nil -> nil
      v -> URI.encode_www_form(v)
    end
    virtual_host = process_vhost(data)

    host = get_in(data, ["hostname"])

    ssl = process_ssl_string(data)

    schema = case ssl do
      false -> "amqp"
      true -> "amqps"
    end

    ssl_props = case ssl do
      false -> ""
      true -> "?verify=verify_none&server_name_indication=#{host}"
    end

    "#{schema}://#{username}:#{password}@#{host}#{virtual_host}#{ssl_props}"
  end

  defp process_vhost(data) do
    case get_in(data, ["virtualhost"]) do
      nil -> ""
      "/" -> ""
      value -> "/#{value}"
    end
  end

  defp process_ssl_string(data) do
    case get_in(data, ["ssl"]) do
      nil -> false
      true -> true
      false -> false
      "true" -> true
      "false" -> false
    end
  end

  defp print_secret(secret_value) do
    masked_secret = Map.replace!(secret_value, "password", "******")
    Logger.debug("Rabbitmq Secret value: #{inspect(masked_secret)}")
  end

end
