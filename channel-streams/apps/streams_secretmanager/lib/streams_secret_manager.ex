defmodule StreamsSecretManager do
  use GenServer
  @behaviour StreamsCore.SecretProvider

  @moduledoc """
  Documentation for `StreamsSecretManager`.
  """

  alias ExAws.SecretsManager
  alias Jason

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(:secret_manager_adapter, [:named_table, read_concurrency: true])
    {:ok, nil}
  end

  @spec get_secret(binary(), any()) :: {:error, any()} | {:ok, any()}
  @doc """
  Gets a secret value
  """
  def get_secret(secret_name, opts \\ []) do
    case :ets.lookup(:secret_manager_adapter, secret_name) do
      [{_, secret}] -> secret
      _ -> GenServer.call(__MODULE__, {:get_secret, secret_name, opts})
    end
  end

  def handle_call({:get_secret, secret_name, opts}, _from, state) do
    {:reply, retrieve_secret(secret_name, opts), state}
  end

  defp retrieve_secret(secret_name, opts) do
    SecretsManager.get_secret_value(secret_name)
    |> ExAws.request
    |> process_response(opts)
    |> ets_insert(secret_name)
  end

  defp ets_insert(result, secret_name) do
    case result do
      {:ok, _} ->
        :ets.insert(:secret_manager_adapter, {secret_name, result})
        result
      _ ->
        result
    end
  end

  defp process_response({:ok, response}, opts) do
    get_in(response, ["SecretString"])
    |> normalize(opts)
  end

  defp process_response({:error, reason}, _opts) do
    Logger.error("Could not fecth secret data, reason: #{inspect(reason)}")
    {:error, reason}
  end

  defp normalize_opts(opts) do
    opts
    |> Enum.into(%{})
  end

  defp normalize(secret_string, opts) do
    case get_in(normalize_opts(opts), [:output]) do
      nil ->
        {:ok, secret_string}
      "json" ->
        {:ok, Jason.decode!(secret_string)}
      _ ->
        {:ok, secret_string}
    end
  end
end
