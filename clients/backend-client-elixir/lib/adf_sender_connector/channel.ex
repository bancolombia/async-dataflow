defmodule AdfSenderConnector.Channel do
  @moduledoc """
  Async Dataflow Rest client for /ext/channel/create endpoint
  """

  use AdfSenderConnector.Spec

  @doc """
  Request Channel Sender to register a channel for the application and user indicated.
  """
  @spec create_channel(pid(), application_ref(), user_ref()) :: {:ok, any()} | {:error, any()}
  def create_channel(pid, application_ref, user_ref) do
    GenServer.call(pid, {:create_channel, application_ref, user_ref})
  end

  ##########################
  # Server Implementation  #
  ##########################

  @doc false
  @impl true
  def handle_call({:create_channel, application_ref, user_ref}, _ctx, state) do
    response = build_new_channel_request(application_ref, user_ref)
    |> request_channel_creation(state)
    |> decode_response

    {:reply, response, state}
  end

  defp build_new_channel_request(application_ref, user_ref) do
    Jason.encode!(%{
      application_ref: application_ref,
      user_ref: user_ref
    })
  end

  defp request_channel_creation(request, state) do
    HTTPoison.post(
      Keyword.fetch!(state, :sender_url) <> "/ext/channel/create",
      request,
      [{"Content-Type", "application/json"}],
      hackney: [:insecure, pool: :default],
      timeout: 10_000, recv_timeout: 10_000, max_connections: 1000
    )
  end



end
