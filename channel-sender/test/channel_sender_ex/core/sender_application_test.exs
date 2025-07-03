defmodule ChannelSenderEx.Core.SenderApplicationTest do
  use ExUnit.Case
  alias ChannelSenderEx.Core.SenderApplication

  test "Should create a new SenderApplication struct" do
    sender_application = SenderApplication.new(name: "app1", id: "1", api_key: "", api_secret: "")
    assert sender_application.name == "app1"
  end

  test "Should create a new SenderApplication with defaults" do
    sender_application = SenderApplication.new()
    assert sender_application.name == nil
  end
end
