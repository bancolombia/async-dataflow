defmodule StreamsHelperConfig.ConfigManager do
  @moduledoc """
  Configuration manager for the application.
  """
  use GenServer

  alias StreamsHelperConfig.ApplicationConfig

  @doc """
  Starts the configuration manager process.
  """
  def start_link(args) do
    file_path_arg = Keyword.get(args, :file_path, nil)
    GenServer.start_link(__MODULE__, file_path_arg, name: __MODULE__)
  end

  def lookup(key) do
    GenServer.call(__MODULE__, {:lookup, key})
  end

  def load(file) do
    GenServer.call(__MODULE__, {:load, file})
  end

  @impl true
  def init(file_path_arg) do
    {:ok, ApplicationConfig.load(file_path_arg)}
  end

  @impl true
  def handle_call({:lookup, key}, _from, data) do
    {:reply, get_in(data, key), data}
  rescue
    _ ->
      {:reply, nil, data}
  end

  @impl true
  def handle_call({:load, file}, _from, _data) do
    new_data = ApplicationConfig.load(file)
    {:reply, new_data, new_data}
  end

end
