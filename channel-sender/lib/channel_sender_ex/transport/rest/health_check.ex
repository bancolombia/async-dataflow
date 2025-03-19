defmodule ChannelSenderEx.Transport.Rest.HealthCheck do

  @moduledoc """
  ExClean2 health check
  """

  def checks do
    [
      %PlugCheckup.Check{name: "http", module: __MODULE__, function: :check_http}
    ]
  end

  def check_http do
    :ok
  end
end
