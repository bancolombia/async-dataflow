defmodule ChannelBridgeEx.Core.Auth.JwtParseOnlyTest do
  use ExUnit.Case

  alias ChannelBridgeEx.Core.Auth.JwtParseOnly

  import Mock

  @moduletag :capture_log

  setup_all do
    #   {:ok, _} = Application.ensure_all_started(:plug_crypto)
    :ok
  end

  setup do
    token =
      "eyJhbGciOiJIUzI1NiJ9.eyJkb2N1bWVudFR5cGUiOiJDQyIsImF1dGhvcml6YXRpb25Db2RlIjoiWHd2TXNaIiwiZG9jdW1lbnROdW1iZXIiOiIxOTg5NjM3MTAwIiwia2lkIjoiUzJGeWJqcGhkM002YTIxek9uVnpMV1ZoYzNRdE1Ub3dNREF3TURBd01EQXdNREE2YTJWNUx6STNNbUZpT0RKa0xUQTFZall0TkdObVl5MDRaamxoTFRWalpUTmxaRFUwTWpBeVpBQUFBQUFFajNTbmhjUWVCS3kxNzJ1Q1d0dUpGNUdQcHZjM3hmenJTK1JjQmhuWHR3K0ttNENDQkRLYzJwc3UrK0xHaHZwaE9tR0pCeXU2ekNIUW1GST0iLCJzY29wZSI6IkJMTSIsImNoYW5uZWwiOiJCTE0iLCJleHAiOjE2MTIzODk4NTcyNTcsImFwcGxpY2F0aW9uLWlkIjoiYWJjMzIxIn0.a1IQIeXFdj1LxWZW3SGWbQe_3OFChd6d2ylcdlJwhyg"

    claims = Jason.decode!("{
      \"documentType\": \"CC\",
      \"authorizationCode\": \"XwvMsZ\",
      \"documentNumber\": \"1989637100\",
      \"kid\": \"S2Fybjphd3M6a21zOnVzLWVhc3QtMTowMDAwMDAwMDAwMDA6a2V5LzI3MmFiODJkLTA1YjYtNGNmYy04ZjlhLTVjZTNlZDU0MjAyZAAAAAAEj3SnhcQeBKy172uCWtuJF5GPpvc3xfzrS+RcBhnXtw+Km4CCBDKc2psu++LGhvphOmGJByu6zCHQmFI=\",
      \"scope\": \"BLM\",
      \"channel\": \"BLM\",
      \"exp\": 1612389857257,
      \"application-id\": \"abc321\"
    }")

    {:ok, init_args: %{token: token}, claims: claims}
  end

  test "Should auth channel", %{init_args: init_args, claims: claims} do
    with_mocks([
      {JwtSupport, [],
       [
         peek_data: fn token ->
           %{
             bearer_token: token,
             claims: claims,
             head: %{}
           }
         end
       ]}
    ]) do
      {:ok, msg} =
        JwtParseOnly.validate_credentials(%{
          "authorization" => init_args.token
        })

      assert msg["documentNumber"] == "1989637100"
      assert msg["authorizationCode"] == "XwvMsZ"
      assert msg["channel"] == "BLM"
    end
  end

  test "Should not auth channel", %{claims: claims} do
    with_mocks([
      {JwtSupport, [],
       [
         peek_data: fn token ->
           %{
             bearer_token: token,
             claims: claims,
             head: %{}
           }
         end
       ]}
    ]) do
      assert {:error, :nocreds} =
               JwtParseOnly.validate_credentials(%{
                 "some-header" => "some-value"
               })
    end
  end
end
