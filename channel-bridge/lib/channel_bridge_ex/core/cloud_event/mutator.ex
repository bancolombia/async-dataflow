defmodule ChannelBridgeEx.Core.CloudEvent.Mutator do
  @moduledoc """
  Definition for a Mutator. A Mutator role is to perform changes to
  the cloud event before is sent to the client via ADF Channel Sender.
  """

  alias ChannelBridgeEx.Core.CloudEvent

  @type cloud_event() :: CloudEvent.t()

  @doc """
  Transform a CloudEvent
  """
  @callback mutate(cloud_event()) :: {:ok, cloud_event()} | {:error, any()}
end
