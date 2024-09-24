defmodule StreamsHelperConfig do
  @moduledoc """
  Documentation for `StreamsHelperConfig`.
  """

  @spec get(list(), any()) :: any()
  def get(key, default) do
    case StreamsHelperConfig.ConfigManager.lookup(key) do
      nil ->
        default
      value ->
        value
    end
  end

  def load(file), do: StreamsHelperConfig.ConfigManager.load(file)

end
