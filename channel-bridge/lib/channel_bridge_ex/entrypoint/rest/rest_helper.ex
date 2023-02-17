defmodule ChannelBridgeEx.Entrypoint.Rest.RestHelper do
  @moduledoc """
  Helper functions for the rest entrypoint router
  """

  alias ChannelBridgeEx.Boundary.ChannelSupervisor
  alias ChannelBridgeEx.Boundary.ChannelManager
  alias ChannelBridgeEx.Boundary.ChannelRegistry
  alias ChannelBridgeEx.Core.Channel
  alias ChannelBridgeEx.Core.Channel.ChannelRequest
  alias ChannelBridgeEx.Core.ErrorResponse

  require Logger

  @type request_data() :: ChannelRequest.t()

  @doc """
  Starts a session and add its first channel.  Session name or key is calculated from data present
  in claims or http request headers. The same goes when calculating the channel key.

  See app env variables :event_routing_session_identifier and :bridge_channel_identifier.

  Those are a list of key values, which this module will search in token claims or request headers,
  concatenate them and build a session-key and channel-key.

  If :event_routing_session_identifier is no present, then the session-key will be the same channel key.
  """
  @spec start_channel(request_data()) :: {Map.t(), Integer.t()}
  def start_channel(request_data) do
    case Channel.new_from_request(request_data) do
      {:ok, channel} ->
        channel
        |> ChannelSupervisor.start_channel_process()
        |> change_status_open
      {:error, reason} ->
        Logger.error("Error starting channel: #{inspect(reason)}")
        handle_error_response({:error, reason})
    end
  end

  @doc """
  Closes a channel within the session. If no channel name provided, closes default channel
  """
  @spec close_channel(request_data()) :: {Map.t(), Integer.t()}
  def close_channel(request_data) do
    case ChannelRequest.extract_channel_alias(request_data) do
      {:ok, channel_alias} ->
        lookup_channel_pid(channel_alias)
        |> change_status_closed
      {:error, reason} ->
        Logger.error("Error closing channel: #{inspect(reason)}")
        handle_error_response({:error, reason})
    end
  end

  defp change_status_open({:ok, channel_pid}) do
    case ChannelManager.open_channel(channel_pid) do
      {:error, _} = error ->
        handle_error_response(error)

      response ->
        ok_response(response)
    end
  end

  defp change_status_open({:error, {:already_started, old_process_id}}) do
    case ChannelManager.open_channel(old_process_id) do
      {:error, _} = error ->
        handle_error_response(error)

      response ->
        ok_response(response)
    end
  end

  defp change_status_open({:error, reason}) when is_atom(reason) do
    handle_error_response({:error, reason})
  end

  defp change_status_closed({:error, :noproc}) do
    handle_error_response({:error, :noproc})
  end

  defp change_status_closed({:ok, pid}) do
    case ChannelManager.close_channel(pid) do
      :ok ->
        ok_response("ok")

      {:error, reason} ->
        Logger.error("Error closing channel: #{reason}")
        handle_error_response({:error, reason})
    end
  end

  defp lookup_channel_pid(channel_alias) do
    case ChannelRegistry.lookup_channel_addr(channel_alias) do
      :noproc ->
        {:error, :noproc}

      pid ->
        {:ok, pid}
    end
  end

  defp handle_error_response({:error, :neveropened}) do
    {%{"errors" => [ErrorResponse.new("", "", "ADF00104", "channel not registered", "")]}, 400}
  end

  defp handle_error_response({:error, :noproc}) do
    # No channel was found with defined alias
    {%{"errors" => [ErrorResponse.new("", "", "ADF00103", "channel not found", "")]}, 400}
  end

  defp handle_error_response({:error, :nosessionidfound}) do
    # No session id was given in request to identify channel alias
    {%{
       "errors" => [
         ErrorResponse.new("", "", "ADF00102", "invalid session-tracker header value", "")
       ]
     }, 400}
  end

  defp handle_error_response({:error, :alreadyclosed}) do
    {%{"errors" => [ErrorResponse.new("", "", "ADF00101", "channel disposed", "")]}, 400}
  end

  defp handle_error_response({:error, :alreadyopen}) do
    {%{"errors" => [ErrorResponse.new("", "", "ADF00100", "channel already registered", "")]},
     400}
  end

  defp handle_error_response({:error, :channel_sender_econnrefused}) do
    {%{"errors" => [ErrorResponse.new("", "", "ADF00105", "ADF Sender error", "")]}, 502}
  end

  defp handle_error_response({:error, :channel_sender_unknown_error}) do
    {%{"errors" => [ErrorResponse.new("", "", "ADF00105", "ADF Sender error", "")]}, 502}
  end

  defp ok_response(response) do
    {%{"result" => response}, 200}
  end
end
