defmodule ChannelSenderEx.Transport.Rest.HealthCheck do
  alias ChannelSenderEx.Persistence.ChannelPersistence
  @moduledoc """
  ExClean2 health check
  """

  def checks do
    [
      %PlugCheckup.Check{name: "http", module: __MODULE__, function: :check_http},
      %PlugCheckup.Check{name: "redis", module: ChannelPersistence, function: :health}
    ]
  end

  def check_http do
    :ok
  end
end
