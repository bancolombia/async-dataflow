defmodule StreamsRestapiAuth.PassthroughProviderTest do
  use ExUnit.Case

  alias StreamsRestapiAuth.PassthroughProvider

  @moduletag :capture_log

  test "should perform no autentication when a token is given" do

    headers = %{
      "content-type" => "application/json",
      "authorization" => "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
      "session-tracker" => "xxxx"
    }

    assert PassthroughProvider.validate_credentials(headers) ==
      {:ok, %{}}

  end

  test "should handle empty header authentication" do

    headers = %{
      "content-type" => "application/json",
      "authorization" => "",
      "session-tracker" => "xxxx"
    }

    assert PassthroughProvider.validate_credentials(headers) == {:ok, %{}}
  end

  test "should handle empty map headers" do

    headers = %{}

    assert PassthroughProvider.validate_credentials(headers) == {:ok, %{}}
  end

end
