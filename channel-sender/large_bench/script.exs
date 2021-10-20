#Create Channel
body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})
start_timing(:create_channel)
{200, _, {:json, json}} = post("/ext/channel/create", [{"content-type", "application/json"}], body)
stop_timing(:create_channel)
inc_counter(:create_channel)
#End Create Channel

#Upgrade connection and Authenticate
channel_ref = Map.get(json, "channel_ref")
channel_secret = Map.get(json, "channel_secret")
delay(400, 0.1)
start_timing(:auth_socket)
{:ok, _headers} = ws_upgrade("/ext/socket?channel=#{channel_ref}")
ws_send_text("Auth::#{channel_secret}")
{:ok, text} = ws_receive_text(25000)
[_, _, "AuthOk", _] = Jason.decode!(text)
stop_timing(:auth_socket)
inc_counter(:auth_socket)
#End Upgrade connection and Authenticate

Stream.repeatedly(fn ->
  start_timing(:heartbeat)
  ws_send_text("hb::1")
  {:ok, text} = ws_receive_text(25000)
  stop_timing(:heartbeat)
  inc_counter(:heartbeat_count)
  case Jason.decode!(text) do
    [tkn_msg_id, "", ":n_token", _new_token] ->
      inc_counter(:new_token_rec)
      ws_send_text("Ack::" <> tkn_msg_id)
      {:ok, text} = ws_receive_text(25000)
      [_, "1", ":hb", _] = Jason.decode!(text)

    [_, "1", ":hb", _] ->
      :ok
  end
  delay(800, 0.1)
end) |> Stream.run()
