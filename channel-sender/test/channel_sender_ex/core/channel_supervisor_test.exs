Code.compiler_options(ignore_module_conflict: true)

defmodule ChannelSenderEx.Core.ChannelSupervisorTest do
  use ExUnit.Case, sync: false
  import Mock

  alias ChannelSenderEx.Core.ChannelSupervisor

  @moduletag :capture_log

  test "Should start supervisor" do
    {:ok, pid} = ChannelSupervisor.start_link(nil)
  end

end
