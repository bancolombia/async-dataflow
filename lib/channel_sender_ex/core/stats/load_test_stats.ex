defmodule LoadTestStats do

  require Logger
  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.Security.ChannelAuthenticator

  def init_stats(gather_time) do
    :ets.new(:register_results, [:ordered_set, :public, :named_table, {:write_concurrency, true}])
    :ets.new(:create_results, [:ordered_set, :public, :named_table, {:write_concurrency, true}])
    SyntheticStatsCollector.start_link("RegisterName", register_name(), gather_time)
    SyntheticStatsCollector.start_link("CreateChannel", create_channel(), gather_time)
  end

  def clean_stats() do
    :ets.delete_all_objects(:register_results)
    :ets.delete_all_objects(:create_results)
  end

  def get_stats_register_name(), do: :ets.tab2list :register_results
  def get_stats_create_channel(), do: :ets.tab2list :create_results

  def stop_logs() do
    Logger.put_module_level(LoadTestStats, :critical)
    Logger.put_module_level(SyntheticStatsCollector, :critical)
  end

  def resume_logs() do
    Logger.put_module_level(LoadTestStats, :info)
    Logger.put_module_level(SyntheticStatsCollector, :info)
  end

  def register_name() do
    create_measurement(
      fn {id, dummy_pid} -> Horde.Registry.register_name({ChannelSenderEx.Core.ChannelRegistry, id}, dummy_pid) end,
      :register_results,
      "Register name",
      fn ->
        dummy_pid = spawn(fn -> Process.sleep(5000) end)
        id = ChannelIDGenerator.generate_channel_id("app_id", "user_ref")
        {id, dummy_pid}
      end
    )
  end


  def create_channel() do
    create_measurement(
      fn _ -> ChannelAuthenticator.create_channel("app32342", "useraaadsdas12122") end,
      :create_results,
      "Create channel"
    )
  end

  def create_measurement(measure_fn, table, desc, prepare_fn \\ fn -> :ok end) do
    fn  ->
      input_data = prepare_fn.()

      {time_us, _} = :timer.tc(fn ->
        measure_fn.(input_data)
      end)

      time_txt = cond do
        time_us > 1000 -> "#{time_us/1000}ms"
        true -> "#{time_us}us"
      end

      Logger.info("#{desc} time: #{time_txt}")
      :ets.insert(table, {:erlang.system_time(), {time_us, time_txt}})
    end
  end

end

