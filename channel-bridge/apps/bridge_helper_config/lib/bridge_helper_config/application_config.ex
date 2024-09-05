defmodule BridgeHelperConfig.ApplicationConfig do
  @moduledoc false
  alias Vapor.Provider.File

  require Logger

  # configuration elements to be loaed as atoms
  @atom_keys [
    [:bridge, "channel_authenticator", "auth_module"],
    [:bridge, "cloud_event_mutator", "mutator_module"],
    [:bridge, "secrets", "provider"]
  ]

  def load(file_path \\ nil) do

    config_file = case file_path do
      e when e in [nil, ""] ->
        raise ArgumentError, "No configuration file specified"
      _ ->
        Logger.info("Loading configuration file #{inspect(file_path)}")
        file_path
    end

    providers = [
      %File{
        path: config_file,
        bindings: [
          {:bridge, "bridge"},
          {:sender, "sender"},
          {:aws, "aws", required: false },
          {:logger, "logger", required: false}
        ]
      }
    ]

    try do
      Vapor.load!(providers)
      |> print_success
      |> load_atoms
      |> set_logging_config
      |> load_system_env
    rescue
      e in Vapor.FileNotFoundError ->
        Logger.error("Error loading configuration: #{inspect(e)}")
        %{}
    end
  end

  defp print_success(config) do
    Logger.info("Configuration file readed successfully")
    config
  end

  defp load_system_env(config) do
    Application.put_env(:channel_bridge, :config, config)
    config
  end

  defp load_atoms(config) do
    @atom_keys
    |> Enum.map(fn(k) ->
      res = get_in(config, k)
      |> String.to_atom
      |> Code.ensure_compiled

      case res do
        {:error, _} ->
          Logger.warning("invalid configuration detected with key #{inspect(k)}. Errors may occur during runtime. #{inspect(res)}")
          {nil, nil}
        {:module, m}  ->
          {k, m}
      end
    end)
    |> Enum.filter(fn({_k, v}) ->
      case v do
        nil ->
          false
        _ -> true
      end
    end)
    |> Enum.reduce(config, fn({k, v}, acc) ->
      put_in(acc, k, v)
    end)
  end

  defp set_logging_config(config) do
    Logger.configure(level: String.to_existing_atom(
      get_with_default(config, [:logger, "level"], "info")
    ), format: "[$level] $metadata$message\n")
    config
  end

  defp get_with_default(config, key, def) do
    case get_in(config, key) do
      nil -> def
      v -> v
    end
  end

end
