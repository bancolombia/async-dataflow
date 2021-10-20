Code.compiler_options(ignore_module_conflict: true)

alias ChannelSenderEx.Core.RulesProvider
alias ChannelSenderEx.Core.RulesProvider.Helper
alias ChannelSenderEx.Core.RulesProvider.Compiler

Helper.compile(:channel_sender_ex)

rules_config = for idx <- 0..1000, do: {String.to_atom("rule#{idx}"), "Some rule configuration value: #{idx}"}
Compiler.compile(Bench.BigConfigRules, rules_config)

Benchee.run(
  %{
    "Noop.." => fn -> for _ <- 0..1000, do: :ok end,
    "Compiled RulesProvider" => fn -> for _ <- 0..1000, do: RulesProvider.get(:socket_port) end,
    "Compiled Rules, 1000 clauses function" => fn -> for _ <- 0..1000, do: Bench.BigConfigRules.get(:rule999) end,
    "Compiled Rules, 1000 clauses function / median" => fn -> for _ <- 0..1000, do: Bench.BigConfigRules.get(:rule500) end,
    "Compiled RulesProvider / tuple value" => fn -> for _ <- 0..1000, do: RulesProvider.get(:secret_base) end,
    "Dynamic Application.get_env" => fn -> for _ <- 0..1000, do: Application.get_env(:channel_sender_ex, :socket_port) end,
    "Dynamic Application.get_env / tuple value" => fn -> for _ <- 0..1000, do: Application.get_env(:channel_sender_ex, :secret_base) end,
  },

  time: 5,
  parallel: 6,
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)