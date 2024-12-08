defmodule ChannelSenderEx.Core.Retry.ExponentialBackoffTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.Retry.ExponentialBackoff

  test "execute/5 retries the action function with exponential backoff" do
    # Setup
    initial = 100
    max_delay = 1000
    max_retries = 3
    action_fn = fn _delay -> :retry end

    # Exercise
    assert ExponentialBackoff.execute(initial, max_delay, max_retries, action_fn, fn -> :void end) == :void
  end

  test "execute/5 retries the action function with exponential backoff, that raises err" do
    # Setup
    initial = 100
    max_delay = 1000
    max_retries = 3
    action_fn = fn _delay -> raise("dummy") end

    # Exercise
    assert ExponentialBackoff.execute(initial, max_delay, max_retries, action_fn, fn -> :void end) == :void
  end

end
