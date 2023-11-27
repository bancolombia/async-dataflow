defmodule AdfSenderConnector.Credentials do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/create endpoint to exchange credentials
  """

  use AdfSenderConnector.Spec

  require Logger

  @doc """
  Request Channel Sender to register a channel for the application and user indicated. Returns appropriate credentials.
  """
  @spec exchange_credentials(pid()) :: {:ok, any()} | {:error, any()}
  def exchange_credentials(pid) do
    GenServer.call(pid, :exchange_credentials)
  end

  ##########################
  # Server Implementation  #
  ##########################

  @doc false
  @impl true
  def handle_call(:exchange_credentials, _ctx, state) do

    response = build_request(state)
      |> send_request(state)
      |> decode_response

    case response do
      {:error, reason} ->
        Logger.error("Error exchanging credentials, #{inspect(reason)}")
      _ ->
        Logger.debug("Credentials exchanged")
        response
    end

    {:reply, response, state}
  end

  defp build_request(state) do
    Jason.encode!(%{
      application_ref: Keyword.fetch!(state, :app_ref),
      user_ref: Keyword.fetch!(state, :user_ref)
    })
  end

  defp send_request(request, state) do
    HTTPoison.post(
      Keyword.fetch!(state, :sender_url) <> "/ext/channel/create",
      request,
      [{"content-type", "application/json"}],
      parse_http_opts(state)
    )
  end

end
