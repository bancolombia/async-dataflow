defmodule EventBusAmqp.Adapter.SecretManager do
  @moduledoc """
  Secrets Manager adapter
  """
  alias ExAws.SecretsManager
  alias Jason

  require Logger

  @doc """
  Gets a secret value
  """
  def get_secret(secret_name, opts \\ []) do
    SecretsManager.get_secret_value(secret_name)
    |> ExAws.request
    |> process_response(opts)
  end

  defp process_response({:ok, response}, opts) do
    get_in(response, ["SecretString"])
    |> (fn(secret) ->
      case get_in(normalize_opts(opts), [:output]) do
        nil ->
          {:ok, secret}
        "json" ->
          {:ok, Jason.decode!(secret)}
        _ ->
          {:ok, secret}
      end
     end).()
  end

  defp process_response({:error, reason}, _opts) do
    Logger.error("Could not fecth secret data, reason: #{inspect(reason)}")
    {:error, reason}
  end

  defp normalize_opts(opts) do
    opts
    |> Enum.into(%{})
  end

end
