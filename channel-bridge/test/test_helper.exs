Code.compiler_options(ignore_module_conflict: true)
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter, ExUnitSonarqube])
ExUnit.start(exclude: [:skip])
