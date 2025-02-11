defmodule AdfSenderConnector.Channel do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel endpoints
  """

  use AdfSenderConnector.Spec

  require Logger

  @doc """
  Request Channel Sender to register a channel for the application and user indicated. Returns appropriate credentials.
  """
  @spec exchange_credentials(application_ref(), user_ref()) :: {:ok, map()} | {:error, any()}
  def exchange_credentials(application_ref, user_ref) when application_ref != nil and user_ref != nil do
    build_request(application_ref, user_ref)
       |> send_post_request("/ext/channel/create")
       |> decode_response
  end

  def exchange_credentials(_application_ref, _user_ref) do
    {:error, :invalid_parameters}
  end

  @doc """
  Request Channel Sender to close a channel.
  """
  @spec close_channel(channel_ref()) :: {:ok, map()} | {:error, any()}
  def close_channel(channel_ref) do
    send_delete_request("/ext/channel?channel_ref=#{channel_ref}")
    |> decode_response
  end

  defp build_request(application_ref, user_ref) do
    Jason.encode!(%{
      application_ref: application_ref,
      user_ref: user_ref
    })
  end

end
