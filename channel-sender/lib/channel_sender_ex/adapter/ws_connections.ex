defmodule ChannelSenderEx.Adapter.WsConnections do

  @service "execute-api"
  @content_type "application/json"

  alias ChannelSenderEx.Core.RulesProvider

  require Logger
  # import ExAws

  def send_data(connection_id, data) when is_binary(connection_id) and connection_id != "" do
    Logger.debug(fn -> "WSConnections: sending data to connection [#{connection_id}]" end)
    endpoint = get_param(:api_gateway_connection, "") <> connection_id
    signed_headers = get_signed_headers(endpoint, get_param(:api_region, "us-east-1"), @service, "POST", data)

    Finch.build(:post, endpoint, signed_headers, data)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def send_data(_, _), do: {:error, :invalid_connection_id}

  def close(connection_id) when is_binary(connection_id) and connection_id != "" do
    Logger.debug(fn -> "WSConnections: requesting close connection [#{connection_id}]" end)
    endpoint = get_param(:api_gateway_connection, "") <> connection_id
    signed_headers = get_signed_headers(endpoint, get_param(:api_region, "us-east-1"), @service, "DELETE", "")

    Finch.build(:delete, endpoint, signed_headers)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def close(_), do: {:error, :invalid_connection_id}

  def get_info(connection_id) do
    endpoint = get_param(:api_gateway_connection, "") <> connection_id
    signed_headers = get_signed_headers(endpoint, get_param(:api_region, "us-east-1"), @service, "GET", "")

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
      {"host", "#{get_param(:api_id, "000")}.execute-api.#{get_param(:api_region, "us-east-1")}.amazonaws.com"},
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

      {:ok, %Finch.Response{status: status, body: body, headers: _headers, trailers: _t}} ->
        Logger.error("Error sending data #{inspect(status)}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Error sending data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
