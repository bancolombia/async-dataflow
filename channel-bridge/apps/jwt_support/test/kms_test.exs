defmodule JwtSupport.KmsHelperTest do
  use ExUnit.Case

  import Mock
  alias JwtSupport.KmsHelper

  @moduletag :capture_log

  test "Should decrypt text" do
    with_mocks([
      {ExAws.KMS, [], [decrypt: fn _text -> %{} end]},
      {ExAws, [], [request: fn _req -> {:ok, %{"Plaintext" => "hello"}} end]}
    ]) do
      assert KmsHelper.decrypt("xxxx") == "hello"
    end
  end

  test "Should fail decrypt text" do
    with_mocks([
      {ExAws.KMS, [], [decrypt: fn _text -> %{} end]},
      {ExAws, [], [request: fn _req -> {:error, "some error"} end]}
    ]) do
      assert KmsHelper.decrypt("xxxx") == :error
    end
  end

end
