Code.compiler_options(ignore_module_conflict: true)

defmodule Test.NewModule do
  def get(_), do: raise("Not compiled")
end

defmodule ChannelSenderEx.Core.RulesProviderTest do
  use ExUnit.Case

  alias ChannelSenderEx.Core.RulesProvider
  alias ChannelSenderEx.Core.RulesProvider.Compiler
  alias ChannelSenderEx.Core.RulesProvider.Helper

  doctest ChannelSenderEx.Core.RulesProvider.Compiler

  test "Should get rules into new module" do
    Compiler.compile(Test.NewModule, rule1: "value1", rule2: {:some, :value})
    assert Test.NewModule.get(:rule1) == "value1"
    assert Test.NewModule.get(:rule2) == {:some, :value}
  end

  test "Should get rules from Application config" do
    Helper.compile(:channel_sender_ex)
    assert RulesProvider.get(:initial_redelivery_time) >= 100
    assert RulesProvider.get(:app_repo) == ChannelSenderEx.Repository.ApplicationRepo
    assert RulesProvider.get(:max_age) >= 100
    assert RulesProvider.get(:socket_port) == 8082
  end

  test "Should single change runtime rule" do
    Helper.compile(:channel_sender_ex)
    assert RulesProvider.get(:initial_redelivery_time) >= 100

    Helper.compile(:channel_sender_ex, initial_redelivery_time: 120)

    assert RulesProvider.get(:initial_redelivery_time) == 120
  end
end
