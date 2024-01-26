defmodule BridgeSecretManager.ApplicationTest do
  use ExUnit.Case, async: true

  test "Should not start app twice" do

    assert {:error, {:already_started, _}} = BridgeSecretManager.Application.start(:normal, [])

  end

end
