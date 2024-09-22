defmodule StreamsApiTest do
  use ExUnit.Case, async: true

  test "Should not start app twice" do

    config = %{
      :streams => %{
        "port" => 8080
      }
    }

    assert {:error, {:already_started, _}} = StreamsApi.start(:normal, [config])

  end

end
