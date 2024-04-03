defmodule BridgeCore.Reference do
  @moduledoc false

  @type channel_ref() :: binary()
  @type channel_secret() :: binary()

  @type t() :: %__MODULE__{
     channel_ref: channel_ref(),
     channel_secret: channel_secret(),
     created_at: DateTime.t(),
     status: atom(),
     updated_at: DateTime.t() | nil,
     last_message_at: DateTime.t() | nil
   }

  defstruct channel_ref: nil,
            channel_secret: nil,
            created_at: nil,
            status: nil,
            updated_at: nil,
            last_message_at: nil

  @spec new(channel_ref(), channel_secret()) :: t()
  def new(channel_ref, channel_secret) do
    %__MODULE__{
      channel_ref: channel_ref,
      channel_secret: channel_secret,
      created_at: DateTime.utc_now(),
      status: :new,
      updated_at: nil,
      last_message_at: nil
    }
  end

end
