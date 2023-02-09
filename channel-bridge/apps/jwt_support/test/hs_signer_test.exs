defmodule JwtSupport.HsSignerTest do
  use ExUnit.Case

  alias JwtSupport.HsSigner
  alias JwtSupport.SignerError

  import Mock

  @moduletag :capture_log

  test "Should build signer HS256" do
    with_mocks([
      {JwtSupport.KmsHelper, [],
       [
         decrypt: fn _text ->
           "qwertyuiopasdfghjklzxcvbnm123456"
         end
       ]}
    ]) do
      signer = HsSigner.build(%{key: "abc"})

      assert signer != nil
    end
  end

  test "Should handle decrypt error" do
    with_mocks([
      {JwtSupport.KmsHelper, [], [decrypt: fn _text -> :error end]}
    ]) do
      assert_raise SignerError, fn ->
        HsSigner.build(%{key: "abc"})
      end
    end
  end

end
