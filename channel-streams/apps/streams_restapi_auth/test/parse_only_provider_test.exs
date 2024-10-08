defmodule StreamsRestapiAuth.JwtParseOnlyProviderTest do
  use ExUnit.Case
  import Mock

  alias StreamsRestapiAuth.JwtParseOnlyProvider

  @moduletag :capture_log

  test "should parse header authentication" do

    headers = %{
      "content-type" => "application/json",
      "authorization" => "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
      "session-tracker" => "xxxx"
    }

    assert JwtParseOnlyProvider.validate_credentials(headers) ==
      {:ok, %{"iat" => 1_516_239_022, "name" => "John Doe", "sub" => "1234567890"}}

  end

  test "should handle empty header authentication" do

    headers = %{
      "content-type" => "application/json",
      "authorization" => "",
      "session-tracker" => "xxxx"
    }

    assert JwtParseOnlyProvider.validate_credentials(headers) == {:error, :nocreds}
  end

  test "should handle empty map headers" do

    headers = %{}

    assert JwtParseOnlyProvider.validate_credentials(headers) == {:error, :nocreds}
  end

  test "should handle decoding error" do

    with_mocks([
      {Jason, [],
        [
          decode!: fn _token ->
            raise "Oh no!"
          end
        ]}
    ]) do

      headers = %{
        "content-type" => "application/json",
        "authorization" => "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
        "session-tracker" => "xxxx"
      }

      assert {:ok, nil} = JwtParseOnlyProvider.validate_credentials(headers)

    end
  end
end
