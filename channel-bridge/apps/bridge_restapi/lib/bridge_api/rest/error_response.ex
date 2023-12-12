defmodule BridgeApi.Rest.ErrorResponse do
  @moduledoc """
  Error definition
  """

  @type reason() :: String.t()
  @type domain() :: String.t()
  @type code() :: String.t()
  @type message() :: String.t()
  @type type() :: String.t()

  @type t() :: %__MODULE__{
          reason: reason(),
          domain: domain(),
          code: code(),
          message: message(),
          type: type()
        }

  @derive Jason.Encoder
  defstruct reason: nil,
            domain: nil,
            code: nil,
            message: nil,
            type: nil

  @doc """
  creates a simple error representation
  """
  @spec new(reason(), domain(), code(), message(), type()) :: t()
  def new(reason, domain, code, message, type) do
    %__MODULE__{
      reason: reason,
      domain: domain,
      code: code,
      message: message,
      type: type
    }
  end
end
