defmodule ChannelSenderEx.Core.ChannelIdGeneratorTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.ChannelIDGenerator
  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.RulesProvider.Helper
  import Mock

  @moduletag :capture_log

  setup_all do
    Application.put_env(:channel_sender_ex, :secret_base, {
      "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc",
      "socket auth"
    })

    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    Helper.compile(:channel_sender_ex)

    on_exit(fn ->
      Application.delete_env(:channel_sender_ex, :secret_base)
    end)

    :ok
  end

  setup do
    {:ok, app_id: "id_app0001", user_id: "user_id_220303"}
  end

  test "Should generate unique ids", %{app_id: app_id, user_id: user_id} do
    :ets.new(:t, [:public, :ordered_set, :named_table, write_concurrency: true])
    num = 100_000
    process = 5

    fn_gen = fn ->
      Enum.each(1..num, fn _ ->
        :ets.insert(:t, {ChannelIDGenerator.generate_channel_id(app_id, user_id)})
      end)
    end

    Enum.map(1..process, fn _ -> Task.async(fn_gen) end) |> Enum.each(&Task.await(&1, 20_000))
    assert num * process == :ets.info(:t, :size)
  end

  test "Should generate token", %{app_id: app_id, user_id: user_id} do
    channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
    token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

    assert {:ok, app_id, user_id} == ChannelIDGenerator.verify_token(channel_id, token)
  end

  test "Should indicate expired token", %{app_id: app_id, user_id: user_id} do
    Helper.compile(:channel_sender_ex, max_age: 1)

    channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
    token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

    Process.sleep(1100)

    assert {:error, :expired} == ChannelIDGenerator.verify_token(channel_id, token)
    Helper.compile(:channel_sender_ex)
  end

  test "Should indicate invalid token", %{app_id: app_id, user_id: user_id} do
    channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)

    token =
      "SFMyNTY.g2gDaANtAAAAQTE2Y2MyNWYzZGU1MDNlZWFhMGFlNjQ4ZWViM2M4MWRjLjFiMzFhZDk4NDFlZDRlYWM5NWQ4ZDA0MGJkMWExYWRhbQAAABBBcHBfaWRfQUxNMDJfUERObQAAABAxMDM3NjA2MD"

    assert {:error, :invalid} == ChannelIDGenerator.verify_token(channel_id, token)
  end

  test "Should indicate wrong channel", %{app_id: app_id, user_id: user_id} do
    channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
    channel_id2 = ChannelIDGenerator.generate_channel_id(app_id, "Other_user")
    token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

    assert {:error, {:different_channel, channel_id, app_id, user_id}} ==
             ChannelIDGenerator.verify_token(channel_id2, token)
  end

  test "Should handle no secret", %{app_id: app_id, user_id: user_id} do
    with_mock Application, get_env: fn _, _ -> nil end do
      channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)

      assert_raise RuntimeError, "Secret base no properly configured for application: ", fn ->
        ChannelIDGenerator.generate_token(channel_id, app_id, user_id)
      end
    end
  end

  test "Should handle RulesProvider error", %{app_id: app_id, user_id: user_id} do
    with_mock RulesProvider, get: fn _ -> raise("dummy") end do
      channel_id = ChannelIDGenerator.generate_channel_id(app_id, user_id)
      token = ChannelIDGenerator.generate_token(channel_id, app_id, user_id)

      assert {:ok, app_id, user_id} == ChannelIDGenerator.verify_token(channel_id, token)
    end
  end
end
