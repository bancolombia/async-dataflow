# Channel Sender

See [Usage Documentation](https://bancolombia.github.io/async-dataflow/docs/channel-sender) for the Channel Sender component of the Async DataFlow project.

# Local Setup

## Requirements

- Elixir >= 1.16
- Mix

## Install

```elixir
mix deps.get
mix compile
```

## Run

In the shell:

```bash
$ iex -S mix
```

or to run several instances locally

```bash
$ MIX_ENV=<CONFIG-FILE-NAME> iex --erl "-name async-node1@127.0.0.1" -S mix

```

## Clients

| Repository |
| -- |
|[Javascript](https://github.com/bancolombia/async-dataflow/tree/master/clients/client-js)|
