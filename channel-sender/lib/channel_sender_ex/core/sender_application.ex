defmodule ChannelSenderEx.Core.SenderApplication do
  @moduledoc """
  """

  defstruct [:name, :id, :api_key, :api_secret]

  @type name() :: String.t()
  @type id() :: String.t()
  @type api_key() :: String.t()
  @type api_secret() :: String.t()

  @type t() :: %ChannelSenderEx.Core.SenderApplication{
          name: name(),
          id: id(),
          api_key: api_key(),
          api_secret: api_secret()
        }

  def new(fields \\ []) do
    struct(__MODULE__, fields)
  end
end
