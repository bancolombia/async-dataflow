defmodule StreamsCore.User do
  @moduledoc """
  An User representation for whom a channel is opened
  """

  require Logger

  @type id() :: String.t()

  @type t() :: %__MODULE__{
          id: id()
        }

  @derive Jason.Encoder
  defstruct id: nil,
            name: nil

  @doc """
  creates a simple user representation
  """
  @spec new(id()) :: struct()
  def new(id) do
    %__MODULE__{
      id: id
    }
  end

end
