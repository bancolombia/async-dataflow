defmodule RestControllerTest do
  use ExUnit.Case

  alias ChannelSenderEx.Transport.Rest.RestController

  @moduletag :capture_log

  doctest RestController

  setup_all do
    {:ok, _} = Application.ensure_all_started(:cowboy)
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:plug_crypto)
    {:ok, _} = Plug.Cowboy.http(RestController, [], port: 9085, protocol_options: [])

    on_exit(fn ->
      :ok = Plug.Cowboy.shutdown(RestController.HTTP)
    end)

    :ok
  end

  test "Should create channel on request" do
    body = Jason.encode!(%{application_ref: "some_application", user_ref: "user_ref_00117ALM"})

    {status, _headers, body} =
      request(:post, "/ext/channel/create", [{"content-type", "application/json"}], body)

    assert 200 == status

    assert %{"channel_ref" => channel_ref, "channel_secret" => channel_secret} =
             Jason.decode!(body)
  end

  test "Should send message on request" do
    body =
      Jason.encode!(%{
        channel_ref: "channel_ref",
        message_id: "message_id",
        correlation_id: "correlation_id",
        message_data: "message_data",
        event_name: "event_name"
      })

    {status, _headers, body} =
      request(:post, "/ext/channel/deliver_message", [{"content-type", "application/json"}], body)

    assert 202 == status
    assert "Ok" == body
  end

  test "Should fail on invalid body" do
    body =
      Jason.encode!(%{
        channel_ref: "channel_ref",
        message_id: "message_id"
      })

    {status, _headers, body} =
      request(:post, "/ext/channel/deliver_message", [{"content-type", "application/json"}], body)

    assert 400 == status
    assert %{"error" => "Invalid request" <> _rest} = Jason.decode!(body)
  end

  defp request(verb, path, headers, body) do
    case :hackney.request(verb, "http://127.0.0.1:9085" <> path, headers, body, []) do
      {:ok, status, headers, client} ->
        {:ok, body} = :hackney.body(client)
        :hackney.close(client)
        {status, headers, body}

      {:error, _} = error ->
        error
    end
  end
end
