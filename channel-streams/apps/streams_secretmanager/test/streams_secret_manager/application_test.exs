defmodule StreamsSecretManager.ApplicationTest do
  use ExUnit.Case, async: true

  test "Should not start app twice" do

    assert {:error, {:already_started, _}} = StreamsSecretManager.Application.start(:normal, [])

  end

end
