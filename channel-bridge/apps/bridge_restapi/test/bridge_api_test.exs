defmodule BridgeApiTest do
  use ExUnit.Case, async: true

  test "Should not start app twice" do

    config = %{
      :bridge => %{
        "port" => 8080
      }
    }

    assert {:error, {:already_started, _}} = BridgeApi.start(:normal, [config])

  end

end
