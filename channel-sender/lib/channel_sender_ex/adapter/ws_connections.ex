defmodule ChannelSenderEx.Adapter.WsConnections do

  @service "execute-api"
  @content_type "application/json"

  alias ChannelSenderEx.Core.RulesProvider

  require Logger
  # import ExAws

  def send_data(connection_id, data) when is_binary(connection_id) and connection_id != "" do
    Logger.debug(fn -> "WSConnections: sending data to connection [#{connection_id}]" end)

    build_endpoint(connection_id)
    |> get_signed_headers(get_param(:api_region, "us-east-1"), @service, "POST", parse_input_data(data))
    |> make_call(:post)

  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def send_data(_, _), do: {:error, :invalid_connection_id}

  def close(connection_id) when is_binary(connection_id) and connection_id != "" do
    Logger.debug(fn -> "WSConnections: requesting close connection [#{connection_id}]" end)

    build_endpoint(connection_id)
    |> get_signed_headers(get_param(:api_region, "us-east-1"), @service, "DELETE", "")
    |> make_call(:delete)

  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  def close(_), do: {:error, :invalid_connection_id}

  defp get_creds() do
    ExAws.Config.new(:apigateway)
    |> get_security_token()
  end

  defp get_security_token(%{access_key_id: id, secret_access_key: key, security_token: nil}) do
    Logger.debug("WSConnections: Getting session token with STS")
    res = ExAws.STS.get_session_token() |> ExAws.request()
    {id, key, res.body.credentials.session_token}
  end

  defp get_security_token(%{access_key_id: id, secret_access_key: key, security_token: token})
       when is_binary(token) do
    Logger.debug("WSConnections: Session token resolved")
    {id, key, token}
  end

  defp get_signed_headers(endpoint, region, service, method, payload) do
    get_creds()
    |> build_pre_headers()
    |> build_sig_headers(endpoint, region, service, method, payload)
  end

  defp build_pre_headers(data = {_access_key, _secret_key, session_token}) do
    Tuple.insert_at(data, 0, [
      {"host", "#{get_param(:api_id, "000")}.execute-api.#{get_param(:api_region, "us-east-1")}.amazonaws.com"},
      {"X-Amz-Security-Token", session_token},
      {"Content-Type", @content_type}
    ])
  end

  defp build_sig_headers({pre_headers, access_key, secret_key, _session_token}, endpoint, region, service, method, payload) do
    {endpoint,
      :aws_signature.sign_v4(
        access_key,
        secret_key,
        region,
        service,
        :calendar.universal_time(),
        method,
        endpoint,
        pre_headers,
        payload,
        []),
      payload}
  end

  defp make_call({endpoint, headers, payload}, method) do
    Finch.build(method, endpoint, headers, payload)
    |> Finch.request(AwsConnectionsFinch)
    |> parse_response
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
        Logger.error("WSConnections: Error sending data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_endpoint(connection_id) do
    get_param(:api_gateway_connection, "") <> connection_id
  end

  defp parse_input_data(data) when is_list(data) do
    List.to_string(data)
  end

  defp parse_input_data(data) when is_binary(data) do
    data
  end

  defp get_param(param, def) do
    RulesProvider.get(param)
  rescue
    _e -> def
  end

end
