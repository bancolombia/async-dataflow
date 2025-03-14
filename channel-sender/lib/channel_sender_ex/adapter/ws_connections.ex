defmodule ChannelSenderEx.Adapter.WsConnections do
  # TODO read from yaml configuration
  @region "us-east-1"
  @api_id "zf2fc0xj0i"
  @stage "galvis"
  @service "execute-api"
  @endopoint "https://#{@api_id}.execute-api.#{@region}.amazonaws.com/#{@stage}/@connections/"
  # @endopoint "http://localhost:3000/"
  @content_type "application/json"
  require Logger
  import ExAws

  def send_data(connection_id, data) do
    Logger.debug("sending data #{data} to connection #{connection_id}")

    endpoint = "#{@endopoint}#{connection_id}"

    signed_headers = get_signed_headers(endpoint, @region, @service, "POST", data)

    Finch.build(:post, endpoint, signed_headers, data)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def close(connection_id) do
    endpoint = "#{@endopoint}#{connection_id}"

    signed_headers = get_signed_headers(endpoint, @region, @service, "DELETE", "")

    Finch.build(:delete, endpoint, signed_headers)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def get_info(connection_id) do
    endpoint = "#{@endopoint}#{connection_id}"

    signed_headers = get_signed_headers(endpoint, @region, @service, "GET", "")

    Finch.build(:get, endpoint, signed_headers)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  defp get_creds() do
    ExAws.Config.new(:apigateway)
    |> get_security_token()
  end

  defp get_security_token(%{access_key_id: id, secret_access_key: key, security_token: nil}) do
    Logger.debug("Getting session token with STS")
    res = ExAws.STS.get_session_token() |> ExAws.request()
    {id, key, res.body.credentials.session_token}
  end

  defp get_security_token(%{access_key_id: id, secret_access_key: key, security_token: token})
       when is_binary(token) do
    Logger.debug("Session token resolved")
    {id, key, token}
  end

  defp get_signed_headers(endpoint, region, service, method, payload) do
    {access_key, secret_key, session_token} = get_creds()

    headers = [
      {"host", "#{@api_id}.execute-api.#{@region}.amazonaws.com"},
      {"X-Amz-Security-Token", session_token},
      {"Content-Type", @content_type}
    ]

    :aws_signature.sign_v4(
      access_key,
      secret_key,
      region,
      service,
      :calendar.universal_time(),
      method,
      endpoint,
      headers,
      payload,
      []
    )
  end

  defp parse_response(response) do
    case response do
      {:ok, %Finch.Response{status: 200, body: _m, headers: _j, trailers: _t}} ->
        :ok

      {:ok, %Finch.Response{status: 204, body: _m, headers: _j, trailers: _t}} ->
        :ok

      {:ok, %Finch.Response{status: status, body: body, headers: _j, trailers: _t}} ->
        Logger.error("Error sending data #{inspect(status)}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Error sending data: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
