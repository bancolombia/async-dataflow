defmodule AdfSenderConnector.Channel do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/create endpoint
  """

  use AdfSenderConnector.Spec
  alias AdfSenderConnector.Router
  require Logger

  @doc """
  Request Channel Sender to register a channel for the application and user indicated.
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
      {:ok, creds} ->
        start_router_process(Map.fetch!(creds, "channel_ref"), state)
      {:error, reason} ->
        Logger.error("Error routing message, #{inspect(reason)}")
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
      [{"Content-Type", "application/json"}],
      parse_http_opts(state)
    )
  end

  defp start_router_process(channel_ref, options) do
    new_options = Keyword.delete(options, :name)
    DynamicSupervisor.start_child(AdfSenderConnector, Router.child_spec([name: channel_ref] ++ new_options))
  end

end
