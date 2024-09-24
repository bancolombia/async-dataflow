defmodule StreamsApi.Rest.RestHelper do
  @moduledoc """
  Helper functions for the rest entrypoint router
  """

  alias AMQP.Application.Channel

  alias StreamsCore.Channel

  alias StreamsApi.Rest.ChannelRequest
  alias StreamsApi.Rest.ErrorResponse

  require Logger

  @type request_data() :: ChannelRequest.t()

  @doc """
  Starts a session and add its first channel.  Session name or key is calculated from data present
  in request body and/or http headers. The same goes when calculating the channel key.

  See configuration option 'cloud_event_channel_identifier'

  Those are a list of key values, which this module will search in token claims or request headers,
  concatenate them and build a session-key and channel-key.

  If :event_routing_session_identifier is no present, then the session-key will be the same channel key.
  """
  @spec start_session(request_data()) :: {map(), integer()}
  def start_session(request_data) do
    with {:ok, channel} <- build_channel_info_from_request(request_data),
         {:ok, {new_channel, _mutator}} <- StreamsCore.start_session(channel) do

      [ref | _tail] = new_channel.procs

      ok_response(%{
        "alias" => new_channel.channel_alias,
        "channel_ref" => ref.channel_ref,
        "channel_secret" => ref.channel_secret
      })

    else
      {:error, reason} ->
        Logger.error("Error starting channel: #{inspect(reason)}")
        handle_error_response({:error, reason})
    end
  end

  @doc """
  Closes a channel within the session. If no channel name provided, closes default channel
  """
  @spec close_channel(request_data()) :: {map(), integer()}
  def close_channel(request_data) do
    case ChannelRequest.extract_channel_alias(request_data) do
      {:ok, channel_alias} ->
        case StreamsCore.end_session(channel_alias) do
          :ok ->
            ok_response("ok")
          {:error, _} = err ->
            handle_error_response(err)
        end
      {:error, reason} ->
        Logger.error("Error closing channel: #{inspect(reason)}")
        handle_error_response({:error, reason})
    end
  end

  # defp change_status_closed({:error, :noproc}) do
  #   handle_error_response({:error, :noproc})
  # end

  # defp change_status_closed({:ok, pid}) do
  #   case ChannelManager.close_channel(pid) do
  #     :ok ->
  #       ok_response("ok")

  #     {:error, reason} ->
  #       Logger.error("Error closing channel: #{reason}")
  #       handle_error_response({:error, reason})
  #   end
  # end

  @spec build_channel_info_from_request(request_data()) :: {:ok, Channel.t()} | {:error, any}
  defp build_channel_info_from_request(request_data) do
    with {:ok, channel_alias} <- ChannelRequest.extract_channel_alias(request_data),
         {:ok, app} <- ChannelRequest.extract_application(request_data),
         {:ok, user} <- ChannelRequest.extract_user_info(request_data) do
      {:ok, Channel.new(channel_alias, app, user)}
    else
      {:error, reason} = err ->
        Logger.error("Error creating channel from request: #{inspect(reason)}")
        err
    end
  end

  # defp handle_error_response({:error, :neveropened}) do
  #   {%{"errors" => [ErrorResponse.new("", "", "ADF00104", "channel not registered", "")]}, 400}
  # end

  defp handle_error_response({:error, :noproc}) do
    # No channel was found with defined alias
    {%{"errors" => [ErrorResponse.new("", "", "ADF00103", "channel not found", "")]}, 400}
  end

  defp handle_error_response({:error, :nosessionidfound}) do
    # No session id was given in request to identify channel alias
    {%{
       "errors" => [
         ErrorResponse.new("", "", "ADF00102", "invalid alias parameter", "")
       ]
     }, 400}
  end

  defp handle_error_response({:error, :alreadyclosed}) do
    #{%{"errors" => [ErrorResponse.new("", "", "ADF00101", "channel disposed", "")]}, 400}
    {%{"result" => "ok"}, 200}
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
