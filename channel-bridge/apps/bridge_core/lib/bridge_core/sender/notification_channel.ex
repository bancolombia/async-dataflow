defmodule BridgeCore.Sender.NotificationChannel do
  @moduledoc """
  Behaviour definition for a notification channel API (i.e Async Dataflow Channel Sender or hosted service like Pusher)
  """

  @type application_ref() :: String.t()
  @type user_ref() :: String.t()
  @type client() :: any()
  @type args() :: map()

  @callback new(args()) :: client()
  @callback create_channel(client(), application_ref(), user_ref()) ::
              {:ok, result :: term} | {:error, reason :: term}
  @callback deliver_message(client(), request :: term) ::
              {:ok, result :: term} | {:error, reason :: term}
end
