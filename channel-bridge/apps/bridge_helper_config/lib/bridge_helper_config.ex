defmodule BridgeHelperConfig do
  @moduledoc """
  Documentation for `BridgeHelperConfig`.
  """

  @spec get(list(), any()) :: any()
  def get(key, default) do
    case BridgeHelperConfig.ConfigManager.lookup(key) do
      nil ->
        default
      value ->
        value
    end
  end

  def load(file), do: BridgeHelperConfig.ConfigManager.load(file)

end
