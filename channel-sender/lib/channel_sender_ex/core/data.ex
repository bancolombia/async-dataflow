defmodule ChannelSenderEx.Core.Data do
  @moduledoc """
  Data module stores the information for the server data
  """

  alias ChannelSenderEx.Core.BoundedMap

  @type pending() :: BoundedMap.t()

  @type t() :: %__MODULE__{
          channel: String.t(),
          application: String.t(),
          socket: String.t(),
          pending: pending(),
          stop_cause: atom(),
          socket_stop_cause: atom(),
          user_ref: String.t(),
          meta: map()
        }

  @derive {Jason.Encoder, only: [:channel, :application, :pending, :user_ref, :socket, :meta]}
  defstruct channel: "",
            application: "",
            socket: nil,
            pending: BoundedMap.new(),
            stop_cause: nil,
            socket_stop_cause: nil,
            user_ref: "",
            meta: nil

  def new(channel, application, user_ref, meta \\ %{}) do
    %__MODULE__{
      channel: channel,
      application: application,
      socket: nil,
      pending: BoundedMap.new(),
      stop_cause: nil,
      socket_stop_cause: nil,
      user_ref: user_ref,
      meta: meta
    }
  end

  def put_in_meta(data = %__MODULE__{}, key, value) do
    %__MODULE__{data | meta: Map.put(data.meta, key, value)}
  end

  def set_pending(data = %__MODULE__{}, pending) do
    %__MODULE__{data | pending: pending}
  end

  def set_socket(data = %__MODULE__{}, socket) do
    %__MODULE__{data | socket: socket}
  end

end
