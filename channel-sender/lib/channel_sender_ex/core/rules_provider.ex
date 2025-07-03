defmodule ChannelSenderEx.Core.RulesProvider do
  @moduledoc """
  Provides general rules for handling timeouts and several communication/protocol related rules
  """
  def get(_key), do: raise("Config has not been compiled yet!")
end

defmodule ChannelSenderEx.Core.RulesProvider.Compiler do
  @moduledoc """
  Compiles essential settings into a dynamic module
  This allows us to read these settings very fast.
  The sole purpose of this module is to take a dynamic module and a keyword list
  and compile it so that the dynamic module returns values of the keyword list
  """

  @doc """
  Compiles a new module embedding the keyword list as functions.
  # Example
      iex> ChannelSenderEx.Core.RulesProvider.Compiler.compile(ChannelSenderEx.Core.RulesProvider, [redis_timeout: 1000, host: "192.168.1.1"])
      iex> ChannelSenderEx.Core.RulesProvider.get(:redis_timeout)
      1000
      iex> ChannelSenderEx.Core.RulesProvider.get(:non_existent_key)
      ** (RuntimeError) CONFIG_NOT_FOUND: :non_existent_key
  """
  def compile(base_module_name, config) do
    # the compile module creates a new module using quote in conjunction with
    # Code.eval_quoted

    # we first create a quote containing the module definition
    # We need `Macro.escape` to escape complex elixir types like maps when used inside quote
    # We also use `location: :keep` to show us the file where this is being done when an error is raised
    unique_id = :erlang.unique_integer([:positive])
    module_name = Module.concat([base_module_name, "Dynamic#{unique_id}"])

    quote bind_quoted: [config: Macro.escape(config), module_name: module_name],
          location: :keep do
      # define our module
      defmodule module_name do
        # for each key value pair in the input keyword list
        for {k, v} <- config do
          # define a function head matching the literal key and return the literal value
          # e.g. def get(:redis_timeout), do: 1000
          def get(unquote(k)), do: unquote(v)
        end

        # if the input key doesn't match any of the previous function heads, it falls down
        # to this default callback where we raise an exception
        def get(any), do: raise("CONFIG_NOT_FOUND: #{inspect(any)}")
      end
    end
    # We have the whole quoted module at this point and we just push it into
    # Code.eval_quoted to compile it.
    |> Code.eval_quoted([], __ENV__)

    module_name
  end
end

defmodule ChannelSenderEx.Core.RulesProvider.Helper do
  @moduledoc false
  alias ChannelSenderEx.Core.RulesProvider.Compiler, as: ModuleCompiler

  def compile(app_name, overrides \\ []) do
    config = Application.get_all_env(app_name) |> Keyword.merge(overrides)
    ModuleCompiler.compile(ChannelSenderEx.Core.RulesProvider, config)
  end
end
