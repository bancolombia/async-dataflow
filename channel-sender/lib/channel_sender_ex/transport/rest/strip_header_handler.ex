defmodule ChannelSenderEx.Transport.Rest.StripHeaderHandler do
  @moduledoc """
  handler to strip 'server' header
  """
  @behaviour :cowboy_stream

  def info(stream_id, {:response, status, headers, body}, state) do
    headers = Map.drop(headers, ["server"])
    :cowboy_stream.info(stream_id, {:response, status, headers, body}, state)
  end

  def info(stream_id, info, state), do: :cowboy_stream.info(stream_id, info, state)

  def init(stream_id, req, opts), do: :cowboy_stream.init(stream_id, req, opts)

  def data(stream_id, is_fin, info, state),
    do: :cowboy_stream.data(stream_id, is_fin, info, state)

  def early_error(stream_id, reason, partial_req, resp, opts),
    do: :cowboy_stream.early_error(stream_id, reason, partial_req, resp, opts)

  def terminate(stream_id, reason, state), do: :cowboy_stream.terminate(stream_id, reason, state)
end
