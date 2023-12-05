defmodule BridgeCore.AppClient do
  @moduledoc """
  An application that uses ADF to route messages to front end
  """

  alias BridgeCore.CloudEvent

  require Logger

  @type id() :: String.t()
  @type name() :: String.t()
  @type cloud_event() :: CloudEvent.t()

  @type t() :: %__MODULE__{
          id: id(),
          name: name()
        }

  @derive Jason.Encoder
  defstruct id: nil,
            name: nil

  @doc """
  creates a simple client application representation
  """
  @spec new(id(), name()) :: t()
  def new(id, name) do
    %__MODULE__{
      id: id,
      name: name
    }
  end

end
