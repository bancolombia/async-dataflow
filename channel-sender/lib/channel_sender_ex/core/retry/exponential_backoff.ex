defmodule ChannelSenderEx.Core.Retry.ExponentialBackoff do
  @moduledoc """
  Exponential backoff algorithm with jitter.
  """
  require Logger

  def execute(initial, max_delay, max_retries, action_fn, on_give_up) do
    loop(initial, max_delay, max_retries, action_fn, normalize(on_give_up), 0)
  end

  defp normalize(value) when is_function(value), do: value
  defp normalize(value) when is_atom(value), do: fn -> exit(value) end

  def loop(_, _, max_retries, _, on_give_up, current_tries) when max_retries == current_tries, do: on_give_up.()

  def loop(initial, max_delay, max_retries, action_fn, on_give_up, iter) do
    actual_delay = exp_back_off(initial, max_delay, iter)
    case do_action(action_fn, actual_delay) do
      :retry -> loop(initial, max_delay, max_retries, action_fn, on_give_up, iter + 1)
      value -> value
    end
  end

  defp do_action(action_fn, actual_delay) do
    {time_us, val} = :timer.tc(fn ->
      try do
        action_fn.(actual_delay)
      catch
        _type, err ->
          Logger.error(err)
          :retry
      end
    end)
    case val do
      :retry ->
        time_ms = time_us / 1_000
        real_time_to_sleep = actual_delay - time_ms
        if real_time_to_sleep > 0 do
          Process.sleep(round(real_time_to_sleep))
        end
        :retry
      value ->
        value
    end

  end

  def jitter(base, factor) when factor < 1 do
    rest = base *  factor
    (base - rest) + (:rand.uniform * rest)
  end

  def exp_back_off(initial, max, iter, jitterFactor \\ 0.2) do
    base = initial * :math.pow(2, iter)
    min(base, max) |> jitter(jitterFactor)
  end

end
