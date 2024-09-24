defmodule StreamsCore.CloudEvent.Mutator do
  @moduledoc """
  Definition for a Mutator. A Mutator role is to perform changes to
  the cloud event before is sent to the client via ADF Channel Sender.
  """

  alias StreamsCore.CloudEvent

  @type cloud_event() :: CloudEvent.t()
  @type config() :: map()

  @doc """
  Function that defines if the mutator should be applied to the cloud event
  """
  @callback applies?(cloud_event(), config()) :: boolean() | {:error, any()}

  @doc """
  Apply the mutator logic to the CloudEvent, an :ok result means the CloudEvent was mutated, else a :noop result means
  the CloudEvent was not mutated due an error invoking the related endpoint.
  """
  @callback mutate(cloud_event(), config()) :: {:ok | :noop, cloud_event()} | {:error, any()}
end
