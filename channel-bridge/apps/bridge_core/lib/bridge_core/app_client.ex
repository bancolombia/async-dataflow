defmodule BridgeCore.AppClient do
  @moduledoc """
  An application that uses ADF to route messages to front end
  """

  require Logger

  @default_channel_inactivity_timeout 420 # in seconds = 7 minutes

  @type id() :: String.t()
  @type name() :: String.t()

  @type t() :: %__MODULE__{
          id: id(),
          name: name(),
          channel_timeout: integer()
        }

  @derive Jason.Encoder
  defstruct id: nil,
            name: nil,
            channel_timeout: 0

  @doc """
  creates a simple client application representation
  """
  @spec new(id(), name(), integer()) :: t()
  def new(id, name, ch_timeout \\ @default_channel_inactivity_timeout) do
    %__MODULE__{
      id: id,
      name: name,
      channel_timeout: ch_timeout
    }
  end

end
