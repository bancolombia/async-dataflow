defmodule ChannelSenderEx.Repository.ApplicationRepo do
  @moduledoc """
  Applications config repository
  """
  alias ChannelSenderEx.Core.SenderApplication

  @type app_id() :: String.t()

  @spec get_application(app_id()) :: {:error, :no_app} | SenderApplication.t()
  def get_application(_app_id) do
    SenderApplication.new(name: "SampleApp")
  end
end
