defmodule StreamsSecretManager.AwsConfig do
  @moduledoc """
  Configures the AWS SDK with the provided configuration.
  """
  require Logger

  def setup_aws_config(config) do
    case get_in(config, [:aws]) do
      nil ->
        config
      awsconf ->
        setup_aws_region(awsconf)
        |> setup_aws_creds
        |> setup_aws_config_secretsmanager
        |> setup_aws_config_debug
    end
  end

  defp setup_aws_region(config) do
    region = case get_in(config, [:region]) do
      nil -> "us-east-1"
      value -> value
    end
    Application.put_env(:ex_aws, :region, region)
    Logger.debug("configured aws default region: #{region}")
    config
  end

  defp setup_aws_config_secretsmanager(config) do
    # secretsmanager config
    case get_in(config, ["secretsmanager"]) do
      nil ->
        Logger.debug("No secretsmanager config present")

      value ->
        value_w_atoms = for {key, val} <- value, into: %{}, do: {String.to_atom(key), val}
        Application.put_env(:ex_aws, :secretsmanager, value_w_atoms |> Map.to_list())
        Logger.debug("secretsmanager config: #{inspect(Application.get_env(:ex_aws, :secretsmanager))}")
    end
    config
  end

  defp setup_aws_creds(config) do
    case get_in(config, ["creds", "access_key_id"]) do
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
      get_in(config, ["creds", "access_key_id"])
      |> Enum.map(fn k ->
        case String.contains?(k, "SYSTEM") do
          true -> fn_system_key.(k)
          false -> fn_instance_role.(k)
        end
      end)

    Application.put_env(:ex_aws, :access_key_id, akid)

    sak =
      get_in(config, ["creds", "secret_access_key"])
      |> Enum.map(fn k ->
        case String.contains?(k, "SYSTEM") do
          true -> fn_system_key.(k)
          false -> fn_instance_role.(k)
        end
      end)

    Application.put_env(:ex_aws, :secret_access_key, sak)

    Logger.debug("configured aws credentials via keys")

    config
  end

  defp setup_aws_config_creds_with_sts(config) do
    Application.put_env(:ex_aws, :secret_access_key, [{:awscli, "profile_name", 30}])
    Application.put_env(:ex_aws, :access_key_id, [{:awscli, "profile_name", 30}])
    Application.put_env(:ex_aws, :awscli_auth_adapter, ExAws.STS.AuthCache.AssumeRoleWebIdentityAdapter)
    Logger.debug("configured aws credentials via STS")
    config
  end

  defp setup_aws_config_debug(config) do
    # Debugging
    case get_in(config, ["debug_requests"]) do
      nil -> Application.put_env(:ex_aws, :debug_requests, false)
      value -> Application.put_env(:ex_aws, :debug_requests, value)
    end
    config
  end

end
