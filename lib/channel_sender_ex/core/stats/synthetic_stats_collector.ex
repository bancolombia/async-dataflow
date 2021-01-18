defmodule SyntheticStatsCollector do
  use GenStateMachine, callback_mode: [:state_functions, :state_enter]
  require Logger

  defstruct [:name, :task, :pid, :delay]

  def start_link(name, task, delay, opts \\ []), do: GenStateMachine.start_link(__MODULE__, {task, name, delay}, opts)

  @impl GenStateMachine
  def init({task, name, delay}), do: {:ok, :waiting, %__MODULE__{name: name, task: task, delay: delay}}

  def waiting(:enter, _, data), do: {:keep_state_and_data, [{:state_timeout, data.delay, :run_task}]}

  def waiting(:state_timeout, :run_task, data = %__MODULE__{task: task}) do
    {pid, _ref} = spawn_monitor(task)
    {:next_state, :running, %{data | pid: pid}}
  end

  def waiting(:info, {:DOWN, _, _, _, :kill}, _), do: :keep_state_and_data

  def waiting(:info, message,  %__MODULE__{name: name}) do
    Logger.info("Task: #{name}, Unexpected info in waiting: #{inspect(message)}")
    :keep_state_and_data
  end

  def running(:enter, _, _), do: {:keep_state_and_data, [{:state_timeout, 15000, :run_timeout}]}

  def running(:state_timeout, :run_timeout, data = %__MODULE__{name: name, pid: pid}) do
    case Process.alive?(pid) do
      false -> Logger.info("Task: #{name}, Process already terminated when timeout")
      true ->
        Logger.warn("Task: #{name}, brutal kill of slow process")
        Process.exit(pid, :kill)
    end
    {:next_state, :waiting, data}
  end

  def running(:info, {:DOWN, _ref, :process, _pid, :normal}, data = %__MODULE__{name: name}) do
    Logger.info("Task: #{name}, task terminated normal")
    {:next_state, :waiting, data}
  end

  def running(:info, {:DOWN, _, _, _, :kill}, _), do: :keep_state_and_data

  def running(:info, {:DOWN, _ref, :process, _pid, reason}, data = %__MODULE__{name: name}) do
    Logger.warn("Task: #{name}, task terminated with reason: #{inspect(reason)}")
    {:next_state, :waiting, data}
  end


end
