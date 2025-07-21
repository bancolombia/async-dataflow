defmodule ChannelSenderEx.Transport.EntryPointTest do
  use ExUnit.Case
  import Mock

  alias ChannelSenderEx.Transport.CowboyStarter
  alias ChannelSenderEx.Transport.EntryPoint

  test "Should load with custom port" do
    with_mock CowboyStarter, start_listeners: fn _ -> :ok end do
      EntryPoint.start(9099)
    end
  end

  test "Should load port from config" do
    with_mock CowboyStarter, start_listeners: fn _ -> :ok end do
      EntryPoint.start()
    end
  end
end
