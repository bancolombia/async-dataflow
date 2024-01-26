defmodule BridgeHelperConfig.ApplicationConfig do
  @moduledoc false
  alias Vapor.Provider.File

  require Logger

  @default_file "config-local.yaml"

  # configuration elements to be loaed as atoms
  @atom_keys [
    [:bridge, "channel_authenticator"],
    [:bridge, "cloud_event_mutator"]
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
      |> load_system_env
      |> load_atoms
      |> set_logging_config
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
    |> Enum.map(fn(k) -> {List.last(k), get_in(config, k)} end)
    |> Enum.filter(fn({k,v}) ->
      case v do
        nil ->
          Logger.warning("invalid configuration for key #{k}, value is nil. Errors may occur during runtime")
          false
        _ -> true
      end
    end)
    |> Enum.map(fn({k,v}) ->
      res = String.to_atom(v)
      |> Code.ensure_compiled
      case res do
        {:error, _} ->
          Logger.warning("invalid configuration for key #{k}, value #{v} is not a valid atom. Errors may occur during runtime")
          nil
        {:module, _}  ->
          v
      end
    end)

    config
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
