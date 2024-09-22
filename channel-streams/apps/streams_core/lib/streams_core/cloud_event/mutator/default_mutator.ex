defmodule StreamsCore.CloudEvent.Mutator.DefaultMutator do
  @moduledoc """
  A mutator performs changes to the cloud event before sending it
  to the client.

  In this case the DefaultMutator does not perform any changes.

  You can create your own mutators by implement the Mutator behaviour.
  """
  @behaviour StreamsCore.CloudEvent.Mutator

  alias StreamsCore.CloudEvent

  @type t() :: CloudEvent.t()

  @doc false
  @impl true
  def applies?(_cloud_event, _config \\ nil) do
    true
  end

  @doc false
  @impl true
  def mutate(cloud_event, _config \\ nil) do
    # No changes are made to the input cloud_event. You can implement mutation functionality here.
    {:ok, cloud_event}
  end

end
