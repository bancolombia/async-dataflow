defmodule ChannelSenderEx.Persistence.RedisConnectionProps do
  @moduledoc false
  require Logger
  @default_port 6379
  @default_host "localhost"

  def resolve_properties(cfg) do
    secret = Keyword.get(cfg, :secret, nil)

    with {:ok, secret_value} <- get_secret_value(secret),
         {:ok, props} <- merge_secret(cfg, secret_value) do
      props
    else
      {:error, reason} ->
        Logger.warning("Error resolving redis properties #{inspect(reason)}")
        raise "Failed to resolve redis properties"
    end
  end

  defp get_secret_value(nil), do: {:ok, %{}}

  defp get_secret_value(secret_name) do
    ExAws.SecretsManager.get_secret_value(secret_name)
    |> ExAws.request()
    |> case do
      {:ok, %{"SecretString" => secret_string}} -> Jason.decode(secret_string)
      {code, rs} -> {code, rs}
      no_expected -> {:error, no_expected}
    end
  end

  defp merge_secret(cfg, secret) do
    host = extract(cfg, secret, :host, @default_host)

    {:ok,
     %{
       host: host,
       hostread: extract(cfg, secret, :hostread, host),
       port: parse_port(extract(cfg, secret, :port, @default_port)),
       username: extract(cfg, secret, :username),
       password: extract(cfg, secret, :password),
       ssl: extract(cfg, secret, :ssl, false)
     }}
  end

  defp extract(cfg, secret, key, default \\ nil) do
    resolve(Keyword.get(cfg, key, default), Map.get(secret, to_string(key)))
  end

  defp resolve(from_config, _from_secret = nil), do: from_config
  defp resolve(_from_config, from_secret), do: from_secret

  defp parse_port(str_port) when is_binary(str_port) do
    {port, _} = Integer.parse(str_port)
    port
  end

  defp parse_port(port), do: port
end
