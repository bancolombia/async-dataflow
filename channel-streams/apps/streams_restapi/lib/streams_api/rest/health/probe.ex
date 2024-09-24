defmodule StreamsApi.Rest.Health.Probe do
  @moduledoc false

  @callback readiness() :: :ok | :error
  @callback liveness() :: :ok | :error

  def liveness, do: :ok
  def readiness, do: :ok
end
