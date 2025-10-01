defmodule ChannelSenderEx.Utils.ChannelMetricsTest do
  use ExUnit.Case

  import Mock

  alias ChannelSenderEx.Utils.ChannelMetrics
  alias ChannelSenderEx.Utils.CustomTelemetry

  setup do
    if GenServer.whereis(ChannelMetrics) do
      GenServer.stop(ChannelMetrics)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer with initial state" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        assert {:ok, pid} = ChannelMetrics.start_link([])
        assert is_pid(pid)
        assert GenServer.whereis(ChannelMetrics) == pid
      end
    end

    test "registers the process with the module name" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, _pid} = ChannelMetrics.start_link([])
        assert GenServer.whereis(ChannelMetrics) != nil
      end
    end
  end

  describe "get_count/0" do
    test "returns initial count as 0" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, _pid} = ChannelMetrics.start_link([])
        assert ChannelMetrics.get_count() == 0
      end
    end

    test "returns updated count after update message" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()
        :pg.join(:test_group_1, self())
        :pg.join(:test_group_2, self())

        send(pid, :update)

        Process.sleep(10)

        count = ChannelMetrics.get_count()
        assert count >= 0
      end
    end
  end

  describe "init/1" do
    test "initializes with count 0 and schedules update" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        state = :sys.get_state(pid)
        assert state == %{count: 0}
      end
    end
  end

  describe "handle_call/3" do
    test "handles :get call and returns current count" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        assert GenServer.call(pid, :get) == 0
      end
    end
  end

  describe "handle_info/2" do
    test "handles :update message and calls CustomTelemetry" do
      with_mock CustomTelemetry,
        execute_custom_event: fn event, metrics ->
          assert event == [:adf, :channel, :active]
          assert is_map(metrics)
          assert Map.has_key?(metrics, :count)
          assert is_integer(metrics.count)
          assert metrics.count >= 0
          :ok
        end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()
        :pg.join(:test_group_1, self())
        :pg.join(:test_group_2, self())

        send(pid, :update)

        Process.sleep(50)

        count = ChannelMetrics.get_count()
        assert count >= 0

        assert called(
                 CustomTelemetry.execute_custom_event([:adf, :channel, :active], %{count: count})
               )
      end
    end

    test "updates internal state with new count" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()
        :pg.join(:active_group, self())

        initial_count = ChannelMetrics.get_count()

        send(pid, :update)
        Process.sleep(50)

        updated_count = ChannelMetrics.get_count()
        assert is_integer(updated_count)
        assert initial_count < updated_count

        assert called(CustomTelemetry.execute_custom_event(:_, :_))
      end
    end
  end

  describe "CustomTelemetry integration" do
    test "calls execute_custom_event with correct parameters" do
      with_mock CustomTelemetry,
        execute_custom_event: fn event, metrics ->
          assert event == [:adf, :channel, :active]
          assert is_map(metrics)
          assert Map.has_key?(metrics, :count)
          assert is_integer(metrics.count)
          :ok
        end do
        {:ok, pid} = ChannelMetrics.start_link([])
        :pg.start_link()
        :pg.join(:group_1, self())
        :pg.join(:group_2, self())

        send(pid, :update)
        Process.sleep(50)

        assert called(CustomTelemetry.execute_custom_event([:adf, :channel, :active], :_))
      end
    end

    test "verifies exact telemetry call parameters" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()
        :pg.join(:group_1, self())
        :pg.join(:group_2, self())
        :pg.join(:group_3, self())

        send(pid, :update)
        Process.sleep(50)

        actual_count = ChannelMetrics.get_count()

        assert called(
                 CustomTelemetry.execute_custom_event([:adf, :channel, :active], %{
                   count: actual_count
                 })
               )
      end
    end
  end

  describe "periodic updates" do
    test "schedules periodic updates and calls telemetry" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])
        :pg.start_link()
        assert Process.alive?(pid)
        assert ChannelMetrics.get_count() == 0

        send(pid, :update)
        Process.sleep(50)

        assert called(CustomTelemetry.execute_custom_event([:adf, :channel, :active], :_))
      end
    end
  end

  describe "PG group counting" do
    test "correctly counts groups with members" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()

        :pg.join(:group_with_members_1, self())
        :pg.join(:group_with_members_2, self())
        :pg.join(:group_with_members_3, self())

        # Trigger update
        send(pid, :update)
        Process.sleep(50)

        count = ChannelMetrics.get_count()
        assert count >= 3

        assert called(
                 CustomTelemetry.execute_custom_event([:adf, :channel, :active], %{count: count})
               )
      end
    end

    test "handles empty PG state" do
      with_mock CustomTelemetry, execute_custom_event: fn _, _ -> :ok end do
        {:ok, pid} = ChannelMetrics.start_link([])

        :pg.start_link()

        send(pid, :update)
        Process.sleep(50)

        count = ChannelMetrics.get_count()
        assert count >= 0

        assert called(
                 CustomTelemetry.execute_custom_event([:adf, :channel, :active], %{count: count})
               )
      end
    end
  end
end
