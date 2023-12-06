defmodule BridgeSecretManagerTest do
  use ExUnit.Case, async: false
  import Mock

  test "Should obtain plain text secret" do
    with_mocks([
      {ExAws.SecretsManager, [], [get_secret_value: fn _name -> %{} end]},
      {ExAws, [], [request: fn _op -> {:ok, %{"SecretString" => "aaa"}} end]},
    ]) do

      result = BridgeSecretManager.get_secret("foo")

      assert {:ok, "aaa"} == result
    end
  end

  test "Should obtain json secret" do
    with_mocks([
      {ExAws.SecretsManager, [], [get_secret_value: fn _name -> %{} end]},
      {ExAws, [], [request: fn _op -> {:ok, %{"SecretString" =>
        "{ \"username\": \"a\", \"password\": \"b\", \"hostname\": \"host\", \"port\": 123 }"
      }} end]},
    ]) do

      result = BridgeSecretManager.get_secret("bar", output: "json")

      assert {:ok, %{"hostname" => "host", "password" => "b", "port" => 123, "username" => "a"}} == result

      # re-query secret
      result2 = BridgeSecretManager.get_secret("bar", output: "json")

      assert result == result2

    end
  end

  test "Should handle error getting secret" do
    with_mocks([
      {ExAws.SecretsManager, [], [get_secret_value: fn _name -> %{} end]},
      {ExAws, [], [request: fn _op -> {:error, "some error"} end]},
    ]) do

      result = BridgeSecretManager.get_secret("acme")

      assert {:error, "some error"} == result

    end
  end
end
