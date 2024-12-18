Code.compiler_options(ignore_module_conflict: true)

defmodule AdfSenderConnector.ApplicationTest do
  use ExUnit.Case

  alias AdfSenderConnector.Application, as: APP

  test "should launch app" do
    assert {:ok, pid} = APP.start(:normal, [])
    Process.exit(pid, :normal)
  end

end
