defmodule ChannelSenderEx.Transport.TransportSpecTest do
  use ExUnit.Case, async: true

  test "my_macro defines the generated_macro function" do
    defmodule TestTransport do
      alias ChannelSenderEx.Transport.TransportSpec
      use TransportSpec
    end

    assert function_exported?(TestTransport, :lookup_channel_addr, 1)
    assert TestTransport.lookup_channel_addr({:error, "foo"}) == {:error, "foo"}
  end

  test "my_macro defines the generated_macro function 2" do
    defmodule TestTransport do
      alias ChannelSenderEx.Transport.TransportSpec
      use TransportSpec, option: :sse
    end

    assert function_exported?(TestTransport, :lookup_channel_addr, 1)
    assert TestTransport.lookup_channel_addr({:error, "foo"}) == {:error, "foo"}
  end
end
