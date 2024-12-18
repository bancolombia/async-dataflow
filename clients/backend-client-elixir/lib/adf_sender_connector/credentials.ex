defmodule AdfSenderConnector.Credentials do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/create endpoint to exchange credentials
  """

  use AdfSenderConnector.Spec

  require Logger

  @doc """
  Request Channel Sender to register a channel for the application and user indicated. Returns appropriate credentials.
  """
  @spec exchange_credentials(application_ref(), user_ref()) :: {:ok, map()} | {:error, any()}
  def exchange_credentials(application_ref, user_ref)
    when application_ref != nil and user_ref != nil do
    response = build_request(application_ref, user_ref)
      |> send_request("/ext/channel/create")
      |> decode_response

      case response do
      {:error, reason} = e ->
        Logger.error("ADF Sender Client - Error exchanging credentials, #{inspect(reason)}")
        e
      _ ->
        Logger.debug("ADF Sender Client - Credentials exchanged")
        response
    end
  end

  def exchange_credentials(_application_ref, _user_ref) do
    Logger.error("ADF Sender Client - invalid parameters for exchange credentials")
    {:error, :channel_sender_bad_request}
  end

  defp build_request(application_ref, user_ref) do
    Jason.encode!(%{
      application_ref: application_ref,
      user_ref: user_ref
    })
  end
end
