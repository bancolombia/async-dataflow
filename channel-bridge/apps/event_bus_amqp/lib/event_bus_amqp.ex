defmodule EventBusAmqp do

  require Logger
  alias EventBusAmqp.Adapter.SecretManager

  def build_child_spec(config) do
    new_config = Map.put_new(config, "broker_url", parse_connection_details(config))
    {EventBusAmqp.Subscriber, [new_config]}
  end

  defp parse_connection_details(config) do
    # If a broker_secret is specified, obtain data from Aws Secretsmanager,
    # otherwise build connection string from explicit keys in file
    case get_in(config, ["broker_secret"]) do
      nil ->
        load_credentials_yaml(config)
      secret_name ->
        load_credentials_secret(secret_name)
    end
  end

  defp load_credentials_yaml(config) do
    Logger.info("Building RabbitMQ credentials from config file...")
    %{
      "username" => get_in(config, ["broker_username"]),
      "password" => URI.encode_www_form(get_in(config, ["broker_password"])),
      "virtualhost" => get_in(config, ["broker_virtualhost"]),
      "hostname" => get_in(config, ["broker_hostname"]),
      "ssl" => get_in(config, ["broker_ssl"])
    }
    |> build_uri
  end

  defp load_credentials_secret(secret_name) do
    Logger.info("Fetching RabbitMQ credentials from a AWS Secret...")
    case SecretManager.get_secret(secret_name, [output: "json"]) do
      {:ok, secret_json} ->
        print_secret(secret_json)
        build_uri(secret_json)
      {:error, reason} ->
        throw(reason)
    end
  end

  defp build_uri(data) do
      username = get_in(data, ["username"])
      password = URI.encode_www_form(get_in(data, ["password"]))
      virtual_host = case get_in(data, ["virtualhost"]) do
        nil -> ""
        "/" -> ""
        value -> "/#{value}"
      end
      host = get_in(data, ["hostname"])

      ssl = case get_in(data, ["ssl"]) do
        nil -> false
        true -> true
        false -> false
        "true" -> true
        "false" -> false
      end

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

  defp print_secret(secret_value) do
    masked_secret = Map.replace!(secret_value, "password", "******")
    Logger.debug("Rabbitmq Secret value: #{inspect(masked_secret)}")
  end

end
