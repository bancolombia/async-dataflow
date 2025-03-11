defmodule ChannelSenderEx.Adapter.WsConnections do

  # TODO read from yaml configuration
  @region "us-east-1"
  @api_id "zf2fc0xj0i"
  @stage "beta"
  @service "execute-api"

  def send_data(connection_id, data) do
    endpoint = "https://#{@api_id}.execute-api.#{@region}.amazonaws.com/#{@stage}/@connections/#{connection_id}"
    signed_headers = get_signed_headers(endpoint, @region, @service, "POST", data)
    Finch.build(:post, endpoint, signed_headers, data) |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      IO.inspect(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def close(connection_id) do
    endpoint = "https://#{@api_id}.execute-api.#{@region}.amazonaws.com/#{@stage}/@connections/#{connection_id}"
    signed_headers = get_signed_headers(endpoint, @region, @service, "DELETE", "")
    Finch.build(:delete, endpoint, signed_headers) |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      IO.inspect(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def get_info(connection_id) do
    endpoint = "https://#{@api_id}.execute-api.#{@region}.amazonaws.com/#{@stage}/@connections/#{connection_id}"
    signed_headers = get_signed_headers(endpoint, @region, @service, "GET", "")
    Finch.build(:get, endpoint, signed_headers) |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      IO.inspect(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  defp get_creds() do
    # TODO use STS to get temporary credentials
    {:ok, access_key} = System.fetch_env("AWS_ACCESS_KEY_ID")
    {:ok, secret_key} = System.fetch_env("AWS_SECRET_ACCESS_KEY")
    session_token = System.get_env("AWS_SESSION_TOKEN")
    {access_key, secret_key, session_token}
  end

  defp get_signed_headers(endpoint, region, service, method, payload) do
    {access_key, secret_key, session_token} = get_creds()
    headers = [
      {"host", "#{@api_id}.execute-api.#{@region}.amazonaws.com"},
      {"X-Amz-Security-Token", session_token}
    ]
    :aws_signature.sign_v4(
      access_key, secret_key, region, service, :calendar.universal_time(), method, endpoint, headers, payload, [])
  end

  defp parse_response(response) do
    case response do
      {:ok, %Finch.Response{status: 200, body: _m, headers: _j, trailers: _t}} -> :ok
      {:ok, %Finch.Response{status: 204, body: _m, headers: _j, trailers: _t}} -> :ok
      {:ok, %Finch.Response{status: _status, body: body, headers: _j, trailers: _t}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

end
